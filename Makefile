PYTHON ?= python3
SWIFT ?= swift
CARGO ?= cargo

.PHONY: doctor repo-lint daemon-build daemon-heartbeat daemon-query-session-list daemon-start-codex-session daemon-reset-session-store daemon-upsert-proof-session daemon-print-session-store-path macos-build probe-session-list probe-codex-session smoke smoke-codex-session

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
	./target/debug/core-daemon --query codex-bootstrap-session

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

smoke: doctor daemon-reset-session-store daemon-upsert-proof-session daemon-heartbeat daemon-query-session-list macos-build probe-session-list

smoke-codex-session: doctor daemon-build macos-build probe-codex-session
