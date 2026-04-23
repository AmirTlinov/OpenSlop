# VISUAL-CHECK

## Surface checked

- Start surface with `Provider=Claude`.
- Claude receipt prompt card.
- Prompt byte counter and validation message.
- Start action disabled/enabled state based on prompt validity.
- Timeline for `claude-turn-proof-latest`.

## Semantic result

PASS by reviewer source check and successful `OpenSlopApp` build.

Verified behavior:
- Claude mode renders a dedicated `Claude receipt prompt` card.
- The card uses receipt/proof copy, not a generic prompt surface.
- The field has a 512 byte budget and empty-state wording for one receipt proof.
- Invalid prompt blocks start before bridge launch.
- Bottom composer remains hidden for Claude receipt sessions.
- Timeline remains read-only receipt evidence.

## Fail-closed visual law

A user may infer that one bounded Claude receipt proof can be created from custom text.

A user must not infer that full Claude dialog, resume, history, native approvals, platform tools or tracing are implemented.

## Verdict

PASS.
