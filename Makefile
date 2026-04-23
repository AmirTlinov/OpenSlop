PYTHON ?= python3
SWIFT ?= swift
CARGO ?= cargo

.PHONY: doctor smoke repo-lint daemon-heartbeat macos-build

doctor: repo-lint

repo-lint:
	$(PYTHON) tools/repo-lint/check_repo_shape.py

daemon-heartbeat:
	$(CARGO) run --quiet -p core-daemon -- --heartbeat

macos-build:
	$(SWIFT) build --package-path apps/macos-app

smoke: doctor daemon-heartbeat macos-build
