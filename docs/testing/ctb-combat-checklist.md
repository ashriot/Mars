# CTB Combat Manual Verification

All checks below are intentionally unchecked until performed interactively in combat. Record the date, OS, input device or connection, resolution, tested commit, and concise pass/fail notes. Automated tests and headless project runs do not count as visual or physical-input acceptance.

## Test setup

- [ ] Launch the project with the isolated test `HOME`, enter a representative combat with multiple heroes and duplicate enemy types, and set the window to `1920x1080`.
- [ ] Exercise mouse, keyboard, controller, and direct touch input where each check names them; a simulated input family does not count as a physical-device pass.

## Queue rail layout

- [ ] The unified rounded rail is black at 90% opacity and keeps icons/text readable over bright combat backgrounds.
- [ ] Hero queue interiors are fully opaque dark cyan and enemy interiors are fully opaque dark magenta, with no battlefield art showing through.
- [ ] Non-current gauges use one bright cyan or magenta readiness arc over the dark-gray track, with no shade layers, nested lines, separators, or pips.
- [ ] The arc begins at top-center and fills clockwise as a turn approaches.
- [ ] The acting battlefield card uses the exact queue gold for the full hero or enemy turn.
- [ ] Target availability, selection outline, and pulse remain independently visible while the acting gold outline persists beneath them.
- [ ] Every queue entry is a uniform `72x72` square, and only the current entry has a gold perimeter.
- [ ] Hero entries use their authored role icon and role color; enemy entries use readable Archivo abbreviations in magenta.
- [ ] At `1920x1080`, the rail exposes at least eight complete queue cards at once and allows inspection of all twenty projected future turns.
- [ ] The inset scrollbar is hidden at the top and remains visible while the rail is displaced.
- [ ] The bottom overflow fade appears only while additional future turns remain below the visible rail and disappears at the end of the list.

## Scrolling and refresh behavior

- [ ] Mouse-wheel input over the full rail, direct touch drag, and right-stick input scroll the same complete turn list without changing the selected action or current target.
- [ ] Preview reorder and preview-clear animations preserve the current rail scroll position.
- [ ] Committing an action and advancing to the next actual turn snap the rail to the top.
- [ ] On advance, the consumed top entry slides left beyond the black rail while fading, visibly above the simultaneously promoted entry.
- [ ] The promoted entry and remaining queue slide upward without covering the consumed entry; visible Fast/Slow crossings still swap positions while their gauges interpolate simultaneously.
- [ ] Hover-preview removals fade in place and never use the committed leftward exit.
- [ ] The leftward exit remains visible outside the rail rather than being clipped at its edge.
- [ ] Rapid target hover changes and rapid input-family handoffs settle on the latest projection without flashes, stale movement, or queue cards stranded between positions.

## Deterministic order and timeline presentation

- [ ] Repeatedly hover the same non-CT target; enemies projected at equal ticks never reorder between identical previews.
- [ ] `80+` ticks is empty, `60` is one quarter, `40` is half, `20` is three quarters, and `0` is full.
- [ ] Changing a hero's current role updates that hero's icons on subsequent projected turns.
- [ ] Duplicate enemies retain readable abbreviations and deterministic A/B/C suffixes throughout the projection.

## Action recovery and CT effects

- [ ] For otherwise identical actions, `75% CT` places the actor earlier than `100% CT`, while `125% CT` places the actor later.
- [ ] Delays visibly drain the arc and boosts visibly fill it without changing unrelated occurrences.
- [ ] The actual current occurrence alone replaces the full faction arc with the full gold perimeter.
- [ ] Action recovery modifiers render white when equal to the authored action value, green when faster, and red when slower.
- [ ] Repeated reactive 10% delays stack below zero instead of clamping after the first delay.

## Target-preview agreement

- [ ] Mouse, keyboard, and controller target changes produce the same queue preview for the same action and target.

## Sign-off

- [ ] Queue rail layout passed — date/OS/resolution/build/notes:
- [ ] Mouse and keyboard interaction passed — device/build/date/notes:
- [ ] Controller interaction passed — device/connection/build/date/notes:
- [ ] Direct touch interaction passed — device/build/date/notes:
- [ ] CT recovery, deterministic order, and preview agreement passed — build/date/notes:
