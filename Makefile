PYTHON ?= python3
SWIFT ?= swift
CARGO ?= cargo

.PHONY: doctor repo-lint daemon-build daemon-heartbeat daemon-query-session-list macos-build probe-session-list smoke

doctor: repo-lint

repo-lint:
	$(PYTHON) tools/repo-lint/check_repo_shape.py

daemon-build:
	$(CARGO) build -p core-daemon

daemon-heartbeat: daemon-build
	./target/debug/core-daemon --heartbeat

daemon-query-session-list: daemon-build
	./target/debug/core-daemon --query session-list

macos-build:
	$(SWIFT) build --package-path apps/macos-app --product OpenSlopApp

probe-session-list: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopProbe

smoke: doctor daemon-heartbeat macos-build probe-session-list
