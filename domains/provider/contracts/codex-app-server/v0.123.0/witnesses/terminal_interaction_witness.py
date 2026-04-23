#!/usr/bin/env python3
from __future__ import annotations

import argparse
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

    def wait_for_response(
        self,
        request_id: int,
        timeout_seconds: float,
        on_message,
    ) -> dict[str, Any]:
        deadline = time.time() + timeout_seconds
        while time.time() < deadline:
            for source, raw_line in self.read_ready_lines(0.25):
                if source == "stderr":
                    self.last_stderr.append(raw_line)
                    self.last_stderr = self.last_stderr[-20:]
                    continue
                try:
                    message = json.loads(raw_line)
                except json.JSONDecodeError as error:
                    raise WitnessFailure(f"invalid JSON line from codex app-server: {error}: {raw_line}") from error
                on_message(message)
                if message.get("id") == request_id:
                    return message
        raise WitnessFailure(
            f"timed out waiting for response id={request_id}; stderr_tail={self.last_stderr}"
        )


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


def run_attempt(
    *,
    repo_root: Path,
    codex_bin: str,
    attempt: int,
    attempt_timeout_seconds: float,
    thread_read_interval_seconds: float,
) -> dict[str, Any]:
    client = JsonLineAppServer(repo_root, codex_bin)
    state: dict[str, Any] = {
        "attempt": attempt,
        "threadId": None,
        "threadStatus": None,
        "lastTurnStatus": None,
        "methods": [],
        "counts": collections.Counter(),
        "terminalInteraction": None,
        "stderrTail": [],
    }

    def on_message(message: dict[str, Any]) -> None:
        method = message.get("method")
        if method:
            state["methods"].append(method)
            state["counts"][method] += 1
            if method == "item/commandExecution/terminalInteraction" and state["terminalInteraction"] is None:
                state["terminalInteraction"] = message
            return

        thread = message.get("result", {}).get("thread")
        if not isinstance(thread, dict):
            return
        state["threadStatus"] = thread.get("status", {}).get("type")
        state["threadId"] = thread.get("id") or state["threadId"]
        turns = thread.get("turns") or []
        if turns:
            state["lastTurnStatus"] = turns[-1].get("status")

    try:
        initialize = client.wait_for_response(
            client.send(
                "initialize",
                {
                    "clientInfo": {
                        "name": "openslop-terminal-interaction-witness",
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
            on_message,
        )
        if "result" not in initialize:
            raise WitnessFailure(f"initialize failed: {initialize}")

        start_thread = client.wait_for_response(
            client.send(
                "thread/start",
                {
                    "cwd": repo_root.as_posix(),
                    "approvalPolicy": "never",
                    "serviceName": "OpenSlopTerminalInteractionWitness",
                    "sessionStartSource": "startup",
                },
            ),
            20,
            on_message,
        )
        thread = start_thread.get("result", {}).get("thread", {})
        if not thread.get("id"):
            raise WitnessFailure(f"thread/start did not return thread id: {start_thread}")
        state["threadId"] = thread["id"]

        start_turn = client.wait_for_response(
            client.send(
                "turn/start",
                {
                    "threadId": state["threadId"],
                    "input": [{"type": "text", "text": DEFAULT_PROMPT}],
                },
            ),
            60,
            on_message,
        )
        if "result" not in start_turn:
            raise WitnessFailure(f"turn/start failed: {start_turn}")

        deadline = time.time() + attempt_timeout_seconds
        next_read_at = time.time()
        while time.time() < deadline and state["terminalInteraction"] is None:
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
                if state["terminalInteraction"] is not None:
                    break

            if state["terminalInteraction"] is not None:
                break

            now = time.time()
            if now >= next_read_at:
                client.send("thread/read", {"threadId": state["threadId"]})
                next_read_at = now + thread_read_interval_seconds

        state["stderrTail"] = client.last_stderr
        return state
    finally:
        client.close()


def print_attempt_summary(result: dict[str, Any]) -> None:
    counts = result["counts"]
    print(
        "attempt="
        f"{result['attempt']} "
        f"thread_id={result.get('threadId') or '—'} "
        f"thread_status={result.get('threadStatus') or '—'} "
        f"last_turn_status={result.get('lastTurnStatus') or '—'} "
        f"terminal_interaction_hits={counts.get('item/commandExecution/terminalInteraction', 0)} "
        f"output_delta_hits={counts.get('item/commandExecution/outputDelta', 0)} "
        f"item_started_hits={counts.get('item/started', 0)} "
        f"item_completed_hits={counts.get('item/completed', 0)}"
    )
    print("methods_seen=" + ",".join(result["methods"]))
    if result.get("terminalInteraction") is not None:
        print(
            "terminal_interaction_payload="
            + json.dumps(result["terminalInteraction"], ensure_ascii=False, separators=(",", ":"))
        )
    elif result.get("stderrTail"):
        print("stderr_tail=" + " | ".join(result["stderrTail"]))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Raw witness for live item/commandExecution/terminalInteraction."
    )
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--codex-bin", default=os.environ.get("CODEX_BIN", "codex"))
    parser.add_argument("--attempts", type=int, default=3)
    parser.add_argument("--attempt-timeout-seconds", type=float, default=75.0)
    parser.add_argument("--thread-read-interval-seconds", type=float, default=1.0)
    args = parser.parse_args()

    try:
        repo_root = args.repo_root or find_repo_root()
        print(f"codex_version={read_codex_version(args.codex_bin)}")

        for attempt in range(1, args.attempts + 1):
            try:
                result = run_attempt(
                    repo_root=repo_root,
                    codex_bin=args.codex_bin,
                    attempt=attempt,
                    attempt_timeout_seconds=args.attempt_timeout_seconds,
                    thread_read_interval_seconds=args.thread_read_interval_seconds,
                )
            except WitnessFailure as error:
                print(f"attempt={attempt} error={error}")
                continue

            print_attempt_summary(result)
            if result.get("terminalInteraction") is not None:
                print(f"terminal_interaction_seen=true seen_on_attempt={attempt}")
                return 0

        print(f"terminal_interaction_seen=false attempts={args.attempts}")
        return 1
    except WitnessFailure as error:
        print(f"witness_error={error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
