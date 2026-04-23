# S01d preflight — native workbench polish

## true_goal

Make the current macOS GUI feel like a real native Codex-style workbench, not an engineering mock shell.

## least_lie_interpretation

This is a narrow visual/native polish slice. It should improve the left rail, central start surface and right inspector tabs without claiming Claude, browser automation, verify or full product completion.

## honest_acceptance

The window recognizably has the target three-zone shape: system left rail, calm central workbench/new-chat surface, right inspector with Summary / Verify / Browser tabs. Runtime truth still comes from daemon and unavailable/planned surfaces are labeled honestly.

## cheap_probe

The user-provided screenshots are the visual probe for this slice: target shape is Image #1, current state is Image #2.

## next_move_for_parent

Patch only the Swift shell presentation surfaces that make the app look fake: SidebarPanelView, TimelinePanelView, InspectorPanelView, ComposerBarView and app window chrome. Do not refactor provider/runtime.

## risks

- Hiding engineering words must not hide real state.
- Browser tab must not pretend S07 is implemented.
- Liquid Glass should come from system chrome/materials on macOS 15; do not invent macOS 26-only APIs without availability gates.
