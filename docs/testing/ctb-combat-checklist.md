# CTB Combat Manual Verification

All checks below are intentionally unchecked until performed interactively in combat. Record the date, OS, input device or connection, resolution, tested commit, and concise pass/fail notes. Automated tests and headless project runs do not count as visual or physical-input acceptance.

## Test setup

- [ ] Launch the project with the isolated test `HOME`, enter a representative combat with multiple heroes and duplicate enemy types, and set the window to `1920x1080`.
- [ ] Exercise mouse, keyboard, controller, and direct touch input where each check names them; a simulated input family does not count as a physical-device pass.

## Active portrait and rail layout

- [ ] During action selection, target hover, target cancel, CT modification previews, condition changes, and Speed changes, the gold active portrait remains first.
- [ ] The larger active portrait remains fixed at the top-right while future-turn cards scroll beneath it.
- [ ] At `1920x1080`, the rail exposes at least eight complete future-turn cards at once and allows inspection of all twenty projected future turns.
- [ ] The bottom overflow fade appears only while additional future turns remain below the visible rail and disappears at the end of the list.

## Scrolling and refresh behavior

- [ ] Right-stick scrolling moves the future-turn rail without changing the selected action or current target.
- [ ] Mouse-wheel input over the rail and direct touch drag scroll the same future-turn list.
- [ ] Hover and preview refreshes preserve the current rail scroll position; advancing to the next actual turn resets the rail to the top.
- [ ] Rapid target hover changes and rapid input-family handoffs never leave queue cards stranded between positions.

## Deterministic order and timeline presentation

- [ ] Repeatedly hover the same non-CT target; enemies projected at equal ticks never reorder between identical previews.
- [ ] Cyan hero and magenta enemy fixed bands retain the same meaning as actors move through the queue.
- [ ] Projections at the `20`, `40`, and `60+` tick boundaries render the expected successive shade layers.
- [ ] Changing a hero's current role updates that hero's icons on subsequent projected turns.
- [ ] Duplicate enemies retain readable abbreviations and deterministic A/B/C suffixes throughout the projection.

## Action recovery and CT effects

- [ ] For otherwise identical actions, `75% CT` places the actor earlier than `100% CT`, while `125% CT` places the actor later.
- [ ] Action recovery modifiers render white when equal to the authored action value, green when faster, and red when slower.
- [ ] Repeated reactive 10% delays stack below zero instead of clamping after the first delay.

## Target-preview agreement

- [ ] Mouse, keyboard, and controller target changes produce the same queue preview for the same action and target.

## Sign-off

- [ ] Active portrait and rail layout passed — date/OS/resolution/build/notes:
- [ ] Mouse and keyboard interaction passed — device/build/date/notes:
- [ ] Controller interaction passed — device/connection/build/date/notes:
- [ ] Direct touch interaction passed — device/build/date/notes:
- [ ] CT recovery, deterministic order, and preview agreement passed — build/date/notes:
