#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]

required_root_files = [
    'AGENTS.md',
    'README.md',
    'PHILOSOPHY.md',
    'ARCHITECTURE.md',
    'DESIGN.md',
    'ROADMAP.md',
    'Makefile',
    '.agents/skills/SKILLS.md',
    '.agents/skills/open-slop-core/SKILL.md',
    '.agents/task_framer/s00-repo-constitution/PREFLIGHT.md',
    'apps/macos-app/Package.swift',
    'services/core-daemon/Cargo.toml',
    'services/core-daemon/src/main.rs',
]

required_domains = [
    'workspace', 'session', 'provider', 'approval', 'git',
    'artifact', 'browser', 'harness', 'verify', 'search'
]

required_slices = [
    'S00-repo-constitution', 'S01-workbench-shell', 'S02-event-spine',
    'S03-codex-runtime', 'S04-transcript-approval-pty', 'S05-claude-runtime',
    'S06-git-review-artifacts', 'S07-browser-preview', 'S08-browser-automation',
    'S09-harness-sensors', 'S10-verify-context-packs', 'S11-scale-search-performance',
    'S12-review-visual-conformance', 'S13-design-accessibility-polish', 'S14-release-engineering'
]

missing = []

for rel in required_root_files:
    if not (ROOT / rel).exists():
        missing.append(rel)

for domain in required_domains:
    for rel in [f'domains/{domain}/AGENTS.md', f'domains/{domain}/docs/context.mmd']:
        if not (ROOT / rel).exists():
            missing.append(rel)

for slug in required_slices:
    for rel in [
        f'plans/slices/{slug}/PLAN.md',
        f'plans/slices/{slug}/TASKS.md',
        f'plans/slices/{slug}/ACCEPTANCE.md',
        f'plans/slices/{slug}/STATUS.md',
        f'plans/slices/{slug}/REVIEW.md',
        f'plans/slices/{slug}/diagrams/flow.mmd',
    ]:
        if not (ROOT / rel).exists():
            missing.append(rel)

if missing:
    print('FAIL repo-shape')
    for item in missing:
        print(f'- missing: {item}')
    sys.exit(1)

print('PASS repo-shape')
