PYTHON ?= python3
SWIFT ?= swift
CARGO ?= cargo

.PHONY: daemon-active-plan-projection doctor repo-lint daemon-build daemon-heartbeat daemon-query-session-list daemon-start-codex-session daemon-read-codex-transcript daemon-submit-codex-turn daemon-execution-profile-status daemon-claude-turn-proof daemon-claude-materialize-proof-session daemon-claude-receipt-snapshot daemon-reset-session-store daemon-upsert-proof-session daemon-print-session-store-path macos-build probe-session-list probe-codex-session probe-codex-turn probe-codex-approval probe-codex-terminal-interaction probe-codex-terminal-surface probe-codex-terminal-tail probe-shell-state probe-timeline-empty-state probe-codex-terminal-interaction-witness probe-codex-live-transcript-control-witness probe-codex-command-exec probe-codex-command-exec-control probe-codex-command-exec-control-surface probe-codex-command-exec-control-negative probe-codex-command-exec-control-timeout probe-codex-command-exec-interactive probe-codex-command-exec-resize probe-codex-command-exec-resize-surface probe-git-review probe-claude-runtime-status probe-claude-turn-proof probe-claude-receipt-session probe-claude-custom-receipt probe-claude-receipt-snapshot probe-execution-profile smoke smoke-codex-session smoke-codex-turn smoke-codex-approval smoke-codex-terminal-interaction smoke-codex-terminal-surface smoke-codex-terminal-tail smoke-shell-state smoke-timeline-empty-state smoke-codex-terminal-interaction-witness smoke-codex-live-transcript-control-witness smoke-codex-command-exec smoke-codex-command-exec-control smoke-codex-command-exec-control-surface smoke-codex-command-exec-control-negative smoke-codex-command-exec-control-timeout smoke-codex-command-exec-interactive smoke-codex-command-exec-resize smoke-codex-command-exec-resize-surface smoke-git-review smoke-claude-runtime-status smoke-claude-turn-proof smoke-claude-receipt-session smoke-claude-custom-receipt smoke-claude-receipt-snapshot smoke-execution-profile probe-active-plan smoke-active-plan

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

daemon-execution-profile-status: daemon-build
	./target/debug/core-daemon --execution-profile-status

daemon-active-plan-projection: daemon-build
	./target/debug/core-daemon --active-plan-projection

daemon-claude-turn-proof: daemon-build
	./target/debug/core-daemon --claude-turn-proof

daemon-claude-materialize-proof-session: daemon-build
	./target/debug/core-daemon --claude-materialize-proof-session

daemon-claude-receipt-snapshot: daemon-build
	./target/debug/core-daemon --claude-receipt-snapshot

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

probe-codex-terminal-interaction: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopTerminalInteractionProbe

probe-codex-terminal-surface: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopTerminalSurfaceProbe

probe-codex-terminal-tail: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopTerminalTailProbe

probe-shell-state:
	$(SWIFT) run --package-path apps/macos-app OpenSlopShellStateProbe

probe-timeline-empty-state:
	$(SWIFT) run --package-path apps/macos-app OpenSlopTimelineEmptyStateProbe

probe-codex-command-exec: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopCommandExecProbe

probe-codex-command-exec-control: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopCommandExecControlProbe

probe-codex-command-exec-control-surface: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopCommandExecControlSurfaceProbe

probe-codex-command-exec-control-negative: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopCommandExecControlNegativeProbe

probe-codex-command-exec-control-timeout: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopCommandExecControlTimeoutProbe

probe-codex-command-exec-interactive: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopCommandExecInteractiveProbe

probe-codex-command-exec-resize: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopCommandExecResizeProbe

probe-codex-command-exec-resize-surface: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopCommandExecResizeSurfaceProbe

probe-git-review: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopGitReviewProbe

probe-claude-runtime-status: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopClaudeStatusProbe

probe-claude-turn-proof: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopClaudeTurnProofProbe

probe-claude-receipt-session: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopClaudeReceiptSessionProbe

probe-claude-custom-receipt: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopClaudeCustomReceiptProbe

probe-claude-receipt-snapshot: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopClaudeReceiptSnapshotProbe

probe-execution-profile: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopExecutionProfileProbe

probe-active-plan: daemon-build
	$(SWIFT) run --package-path apps/macos-app OpenSlopActivePlanProbe

probe-codex-terminal-interaction-witness:
	$(PYTHON) domains/provider/contracts/codex-app-server/v0.123.0/witnesses/terminal_interaction_witness.py

probe-codex-live-transcript-control-witness:
	$(PYTHON) domains/provider/contracts/codex-app-server/v0.123.0/witnesses/live_transcript_control_witness.py

smoke: doctor daemon-reset-session-store daemon-upsert-proof-session daemon-heartbeat daemon-query-session-list macos-build probe-session-list

smoke-codex-session: doctor daemon-build macos-build probe-codex-session

smoke-codex-turn: doctor daemon-build macos-build probe-codex-turn

smoke-codex-approval: doctor daemon-build macos-build probe-codex-approval

smoke-codex-terminal-interaction: doctor daemon-build macos-build probe-codex-terminal-interaction

smoke-codex-terminal-surface: doctor daemon-build macos-build probe-codex-terminal-surface

smoke-codex-terminal-tail: doctor daemon-build macos-build probe-codex-terminal-tail

smoke-shell-state: doctor macos-build probe-shell-state

smoke-timeline-empty-state: doctor macos-build probe-timeline-empty-state

smoke-codex-command-exec: doctor daemon-build macos-build probe-codex-command-exec

smoke-codex-command-exec-control: doctor daemon-build macos-build probe-codex-command-exec-control

smoke-codex-command-exec-control-surface: doctor daemon-build macos-build probe-codex-command-exec-control-surface

smoke-codex-command-exec-control-negative: doctor daemon-build macos-build probe-codex-command-exec-control-negative

smoke-codex-command-exec-control-timeout: doctor daemon-build macos-build probe-codex-command-exec-control-timeout

smoke-codex-command-exec-interactive: doctor daemon-build macos-build probe-codex-command-exec-interactive

smoke-codex-command-exec-resize: doctor daemon-build macos-build probe-codex-command-exec-resize

smoke-codex-command-exec-resize-surface: doctor daemon-build macos-build probe-codex-command-exec-resize-surface

smoke-git-review: doctor daemon-build macos-build probe-git-review

smoke-claude-runtime-status: doctor daemon-build macos-build probe-claude-runtime-status

smoke-claude-turn-proof: doctor daemon-build macos-build probe-claude-turn-proof

smoke-claude-receipt-session: doctor daemon-build macos-build probe-claude-receipt-session

smoke-claude-custom-receipt: doctor daemon-build macos-build probe-claude-custom-receipt

smoke-claude-receipt-snapshot: doctor daemon-build macos-build probe-claude-receipt-snapshot

smoke-execution-profile: doctor daemon-build macos-build probe-execution-profile

smoke-active-plan: doctor daemon-build macos-build probe-active-plan

smoke-codex-terminal-interaction-witness: doctor probe-codex-terminal-interaction-witness

smoke-codex-live-transcript-control-witness: doctor probe-codex-live-transcript-control-witness
