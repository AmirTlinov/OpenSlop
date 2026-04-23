#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import collections
import json
import os
import select
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

DEFAULT_PROMPT = """Use the shell to run exactly: python3 -c "print('READY'); input(); print('DONE')".
Do not skip the command.
After you observe what happens, reply with exactly FINISHED."""
DEFAULT_WRITE_TEXT = "PING\n"
REJECTION_SNIPPET = "no active command/exec for process id"


class WitnessFailure(RuntimeError):
    pass


class JsonLineAppServer:
    def __init__(self, repo_root: Path, codex_bin: str) -> None:
        self.process = subprocess.Popen(
            [codex_bin, "app-server", "--listen", "stdio://"],
            cwd=repo_root,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self.next_id = 1
        self.last_stderr: list[str] = []

    def close(self) -> None:
        if self.process.poll() is None:
            self.process.kill()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()

    def send(self, method: str, params: dict[str, Any]) -> int:
        if self.process.stdin is None:
            raise WitnessFailure("codex app-server stdin is unavailable")
        request_id = self.next_id
        self.next_id += 1
        payload = {"id": request_id, "method": method, "params": params}
        self.process.stdin.write(json.dumps(payload) + "\n")
        self.process.stdin.flush()
        return request_id

    def read_ready_lines(self, timeout_seconds: float) -> list[tuple[str, str]]:
        streams = []
        if self.process.stdout is not None:
            streams.append(self.process.stdout)
        if self.process.stderr is not None:
            streams.append(self.process.stderr)
        if not streams:
            return []

        readable, _, _ = select.select(streams, [], [], timeout_seconds)
        lines: list[tuple[str, str]] = []
        for stream in readable:
            line = stream.readline()
            if not line:
                continue
            source = "stderr" if stream is self.process.stderr else "stdout"
            lines.append((source, line.rstrip("\n")))
        return lines


def find_repo_root() -> Path:
    current = Path(__file__).resolve()
    for candidate in [current.parent, *current.parents]:
        if (candidate / "AGENTS.md").exists() and (candidate / "Cargo.toml").exists():
            return candidate
    raise WitnessFailure("could not locate OpenSlop repo root from witness path")


def read_codex_version(codex_bin: str) -> str:
    process = subprocess.run(
        [codex_bin, "--version"],
        text=True,
        capture_output=True,
        check=False,
    )
    if process.returncode != 0:
        raise WitnessFailure(process.stderr.strip() or "failed to read codex version")
    return process.stdout.strip()


def json_error_summary(message: dict[str, Any]) -> str | None:
    error = message.get("error")
    if not isinstance(error, dict):
        return None
    code = error.get("code")
    text = error.get("message")
    return f"code={code} message={text}"


def escape_text(text: str | None) -> str:
    if text is None:
        return "—"
    return text.encode("unicode_escape").decode("ascii")


def maybe_thread_id(message: dict[str, Any]) -> str | None:
    params = message.get("params")
    if isinstance(params, dict):
        thread_id = params.get("threadId")
        if isinstance(thread_id, str):
            return thread_id
    result = message.get("result")
    if isinstance(result, dict):
        thread = result.get("thread")
        if isinstance(thread, dict):
            thread_id = thread.get("id")
            if isinstance(thread_id, str):
                return thread_id
    return None


def run_attempt(
    *,
    repo_root: Path,
    codex_bin: str,
    attempt: int,
    attempt_timeout_seconds: float,
    thread_read_interval_seconds: float,
    write_text: str,
) -> dict[str, Any]:
    client = JsonLineAppServer(repo_root, codex_bin)
    state: dict[str, Any] = {
        "attempt": attempt,
        "threadId": None,
        "threadStatus": None,
        "lastTurnStatus": None,
        "methods": [],
        "counts": collections.Counter(),
        "terminalInteractions": [],
        "firstProcessId": None,
        "commandItem": None,
        "writeResponse": None,
        "closeResponse": None,
        "writeAttempted": False,
        "stderrTail": [],
        "verdict": "no_terminal_interaction",
        "reason": None,
    }

    def on_message(message: dict[str, Any]) -> None:
        method = message.get("method")
        if method:
            message_thread_id = maybe_thread_id(message)
            if state["threadId"] is not None and message_thread_id is not None and message_thread_id != state["threadId"]:
                return
            state["methods"].append(method)
            state["counts"][method] += 1
            params = message.get("params") if isinstance(message.get("params"), dict) else {}
            if method == "item/commandExecution/terminalInteraction":
                state["terminalInteractions"].append(params)
                if state["firstProcessId"] is None:
                    state["firstProcessId"] = params.get("processId")
            elif method == "item/completed":
                item = params.get("item") if isinstance(params, dict) else None
                if isinstance(item, dict) and item.get("type") == "commandExecution":
                    process_id = item.get("processId")
                    if state["firstProcessId"] is None or process_id == state["firstProcessId"]:
                        state["commandItem"] = item
            return

        thread = message.get("result", {}).get("thread")
        if not isinstance(thread, dict):
            return
        state["threadStatus"] = thread.get("status", {}).get("type")
        state["threadId"] = thread.get("id") or state["threadId"]
        turns = thread.get("turns") or []
        if turns:
            state["lastTurnStatus"] = turns[-1].get("status")
            items = turns[-1].get("items") or []
            for item in items:
                if not isinstance(item, dict) or item.get("type") != "commandExecution":
                    continue
                process_id = item.get("processId")
                if state["firstProcessId"] is None or process_id == state["firstProcessId"]:
                    state["commandItem"] = item

    def wait_for_response(request_id: int, timeout_seconds: float) -> dict[str, Any]:
        deadline = time.time() + timeout_seconds
        while time.time() < deadline:
            for source, raw_line in client.read_ready_lines(0.25):
                if source == "stderr":
                    client.last_stderr.append(raw_line)
                    client.last_stderr = client.last_stderr[-20:]
                    continue
                try:
                    message = json.loads(raw_line)
                except json.JSONDecodeError as error:
                    raise WitnessFailure(f"invalid JSON line from codex app-server: {error}: {raw_line}") from error
                on_message(message)
                if message.get("id") == request_id:
                    return message
        raise WitnessFailure(
            f"timed out waiting for response id={request_id}; stderr_tail={client.last_stderr}"
        )

    try:
        initialize = wait_for_response(
            client.send(
                "initialize",
                {
                    "clientInfo": {
                        "name": "openslop-live-transcript-control-witness",
                        "version": "0.1.0",
                    },
                    "capabilities": {
                        "optOutNotificationMethods": [
                            "thread/started",
                            "turn/started",
                            "turn/completed",
                        ]
                    },
                },
            ),
            20,
        )
        if "result" not in initialize:
            raise WitnessFailure(f"initialize failed: {initialize}")

        start_thread = wait_for_response(
            client.send(
                "thread/start",
                {
                    "cwd": repo_root.as_posix(),
                    "approvalPolicy": "never",
                    "serviceName": "OpenSlopLiveTranscriptControlWitness",
                    "sessionStartSource": "startup",
                },
            ),
            20,
        )
        thread = start_thread.get("result", {}).get("thread", {})
        if not thread.get("id"):
            raise WitnessFailure(f"thread/start did not return thread id: {start_thread}")
        state["threadId"] = thread["id"]

        start_turn = wait_for_response(
            client.send(
                "turn/start",
                {
                    "threadId": state["threadId"],
                    "input": [{"type": "text", "text": DEFAULT_PROMPT}],
                },
            ),
            60,
        )
        if "result" not in start_turn:
            raise WitnessFailure(f"turn/start failed: {start_turn}")

        deadline = time.time() + attempt_timeout_seconds
        next_read_at = time.time()
        while time.time() < deadline:
            for source, raw_line in client.read_ready_lines(0.25):
                if source == "stderr":
                    client.last_stderr.append(raw_line)
                    client.last_stderr = client.last_stderr[-20:]
                    continue
                try:
                    message = json.loads(raw_line)
                except json.JSONDecodeError as error:
                    raise WitnessFailure(
                        f"invalid JSON line from codex app-server: {error}: {raw_line}"
                    ) from error
                on_message(message)

                if state["firstProcessId"] is not None and not state["writeAttempted"]:
                    state["writeAttempted"] = True
                    state["writeResponse"] = wait_for_response(
                        client.send(
                            "command/exec/write",
                            {
                                "processId": state["firstProcessId"],
                                "deltaBase64": base64.b64encode(write_text.encode()).decode(),
                                "closeStdin": False,
                            },
                        ),
                        10,
                    )
                    state["closeResponse"] = wait_for_response(
                        client.send(
                            "command/exec/write",
                            {
                                "processId": state["firstProcessId"],
                                "closeStdin": True,
                            },
                        ),
                        10,
                    )

            now = time.time()
            if now >= next_read_at:
                client.send("thread/read", {"threadId": state["threadId"]})
                next_read_at = now + thread_read_interval_seconds

            if state["writeAttempted"] and state["commandItem"] is not None and state["threadStatus"] == "idle":
                break

        if state["firstProcessId"] is None:
            state["verdict"] = "no_terminal_interaction"
            state["reason"] = "no live item/commandExecution/terminalInteraction arrived"
        else:
            write_error = json_error_summary(state["writeResponse"] or {})
            close_error = json_error_summary(state["closeResponse"] or {})
            post_write_inputs = [
                interaction.get("stdin")
                for interaction in state["terminalInteractions"][1:]
                if isinstance(interaction.get("stdin"), str)
            ]
            if write_error and REJECTION_SNIPPET in write_error:
                state["verdict"] = "rejected"
                state["reason"] = write_error
            elif close_error and REJECTION_SNIPPET in close_error:
                state["verdict"] = "rejected"
                state["reason"] = close_error
            elif any(write_text in (payload or "") for payload in post_write_inputs):
                state["verdict"] = "confirmed"
                state["reason"] = "post-write terminalInteraction echoed witness stdin"
            else:
                state["verdict"] = "ambiguous"
                state["reason"] = write_error or close_error or "write accepted without visible post-write terminal signal"

        state["stderrTail"] = client.last_stderr
        return state
    finally:
        client.close()


def print_attempt_summary(result: dict[str, Any]) -> None:
    counts = result["counts"]
    terminal_payloads = [escape_text(item.get("stdin")) for item in result.get("terminalInteractions", [])]
    command_item = result.get("commandItem") or {}
    write_error = json_error_summary(result.get("writeResponse") or {})
    close_error = json_error_summary(result.get("closeResponse") or {})
    print(
        "attempt="
        f"{result['attempt']} "
        f"thread_id={result.get('threadId') or '—'} "
        f"thread_status={result.get('threadStatus') or '—'} "
        f"last_turn_status={result.get('lastTurnStatus') or '—'} "
        f"terminal_interaction_hits={counts.get('item/commandExecution/terminalInteraction', 0)} "
        f"command_started_hits={counts.get('item/started', 0)} "
        f"command_completed_hits={counts.get('item/completed', 0)} "
        f"process_id={result.get('firstProcessId') or '—'}"
    )
    print("methods_seen=" + ",".join(result["methods"]))
    print("terminal_payloads=" + ("|".join(terminal_payloads) if terminal_payloads else "—"))
    print("write_response_error=" + (write_error or "none"))
    print("close_response_error=" + (close_error or "none"))
    if command_item:
        print(
            "command_item="
            + json.dumps(
                {
                    "status": command_item.get("status"),
                    "processId": command_item.get("processId"),
                    "exitCode": command_item.get("exitCode"),
                    "aggregatedOutput": command_item.get("aggregatedOutput"),
                },
                ensure_ascii=False,
                separators=(",", ":"),
            )
        )
    print("attempt_verdict=" + result.get("verdict", "unknown"))
    print("attempt_reason=" + str(result.get("reason") or "—"))
    if result.get("stderrTail"):
        print("stderr_tail=" + " | ".join(result["stderrTail"]))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Raw witness for live transcript processId -> command/exec/write feasibility."
    )
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--codex-bin", default=os.environ.get("CODEX_BIN", "codex"))
    parser.add_argument("--attempts", type=int, default=5)
    parser.add_argument("--attempt-timeout-seconds", type=float, default=75.0)
    parser.add_argument("--thread-read-interval-seconds", type=float, default=1.0)
    parser.add_argument("--write-text", default=DEFAULT_WRITE_TEXT)
    args = parser.parse_args()

    try:
        repo_root = args.repo_root or find_repo_root()
        print(f"codex_version={read_codex_version(args.codex_bin)}")

        best_result: dict[str, Any] | None = None
        for attempt in range(1, args.attempts + 1):
            try:
                result = run_attempt(
                    repo_root=repo_root,
                    codex_bin=args.codex_bin,
                    attempt=attempt,
                    attempt_timeout_seconds=args.attempt_timeout_seconds,
                    thread_read_interval_seconds=args.thread_read_interval_seconds,
                    write_text=args.write_text,
                )
            except WitnessFailure as error:
                print(f"attempt={attempt} error={error}")
                continue

            print_attempt_summary(result)
            best_result = result
            if result.get("verdict") in {"confirmed", "rejected"}:
                print("live_transcript_control_feasibility=" + result["verdict"])
                print("live_transcript_control_reason=" + str(result.get("reason") or "—"))
                return 0

        if best_result is not None:
            print("live_transcript_control_feasibility=" + str(best_result.get("verdict") or "unknown"))
            print("live_transcript_control_reason=" + str(best_result.get("reason") or "—"))
        else:
            print("live_transcript_control_feasibility=no_result")
            print("live_transcript_control_reason=no successful witness attempt")
        return 1
    except WitnessFailure as error:
        print(f"witness_error={error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
