PYTHON ?= python3
SWIFT ?= swift
CARGO ?= cargo

.PHONY: doctor repo-lint daemon-build daemon-heartbeat daemon-query-session-list daemon-start-codex-session daemon-read-codex-transcript daemon-submit-codex-turn daemon-reset-session-store daemon-upsert-proof-session daemon-print-session-store-path macos-build probe-session-list probe-codex-session probe-codex-turn probe-codex-approval probe-codex-terminal-interaction-witness smoke smoke-codex-session smoke-codex-turn smoke-codex-approval smoke-codex-terminal-interaction-witness

doctor: repo-lint

repo-lint:
	$(PYTHON) tools/repo-lint/check_repo_shape.py

daemon-build:
	$(CARGO) build -p core-daemon

daemon-heartbeat: daemon-build
	./target/debug/core-daemon --heartbeat

daemon-query-session-list: daemon-build
	./target/debug/core-daemon --query session-list

daemon-start-codex-session: daemon-build
	./target/debug/core-daemon --start-codex-session

daemon-read-codex-transcript: daemon-build
	./target/debug/core-daemon --read-codex-transcript "$(SESSION_ID)" _

daemon-submit-codex-turn: daemon-build
	./target/debug/core-daemon --submit-codex-turn "$(SESSION_ID)" "$(INPUT)"

daemon-reset-session-store: daemon-build
	./target/debug/core-daemon --reset-session-store

daemon-upsert-proof-session: daemon-build
	./target/debug/core-daemon --upsert-proof-session

daemon-print-session-store-path: daemon-build
	./target/debug/core-daemon --print-session-store-path

macos-build:
	$(SWIFT) build --package-path apps/macos-app --product OpenSlopApp

probe-session-list: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopProbe

probe-codex-session: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopCodexProbe

probe-codex-turn: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopTurnProbe

probe-codex-approval: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopApprovalProbe

probe-codex-terminal-interaction-witness:
	$(PYTHON) domains/provider/contracts/codex-app-server/v0.123.0/witnesses/terminal_interaction_witness.py

smoke: doctor daemon-reset-session-store daemon-upsert-proof-session daemon-heartbeat daemon-query-session-list macos-build probe-session-list

smoke-codex-session: doctor daemon-build macos-build probe-codex-session

smoke-codex-turn: doctor daemon-build macos-build probe-codex-turn

smoke-codex-approval: doctor daemon-build macos-build probe-codex-approval

smoke-codex-terminal-interaction-witness: doctor probe-codex-terminal-interaction-witness
