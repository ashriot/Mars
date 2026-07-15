# CTB Combat Manual Verification

All checks below are intentionally unchecked until performed interactively in combat. Record the date, OS, input device or connection, resolution, tested commit, and concise pass/fail notes. Automated tests and headless project runs do not count as visual or physical-input acceptance.

## Test setup

- [ ] Launch the project with the isolated test `HOME`, enter a representative combat with multiple heroes and duplicate enemy types, and set the window to `1920x1080`.
- [ ] Exercise mouse, keyboard, controller, and direct touch input where each check names them; a simulated input family does not count as a physical-device pass.

## Queue rail layout

- [ ] The unified rounded rail is black at 90% opacity and keeps icons/text readable over bright combat backgrounds.
- [ ] Non-current gauges show a subtle dark-gray track with same-width opaque light, medium, and dark faction strokes covering one another, with no nested colored outlines.
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
- [ ] An advance fades the consumed entry while the remaining entries slide upward; visible Fast/Slow crossings swap positions while their gauges interpolate simultaneously.
- [ ] Rapid target hover changes and rapid input-family handoffs settle on the latest projection without flashes, stale movement, or queue cards stranded between positions.

## Deterministic order and timeline presentation

- [ ] Repeatedly hover the same non-CT target; enemies projected at equal ticks never reorder between identical previews.
- [ ] Cyan hero and magenta enemy fixed bands retain the same meaning as actors move through the queue.
- [ ] Projections at the `20`, `40`, and `60+` tick boundaries render the expected successive shade layers.
- [ ] Changing a hero's current role updates that hero's icons on subsequent projected turns.
- [ ] Duplicate enemies retain readable abbreviations and deterministic A/B/C suffixes throughout the projection.

## Action recovery and CT effects

- [ ] For otherwise identical actions, `75% CT` places the actor earlier than `100% CT`, while `125% CT` places the actor later.
- [ ] Ordinary actors near the battle median show standard recovery at around two gauge bands instead of every future perimeter appearing full.
- [ ] Before other CT changes, `75%`, `100%`, `125%`, and `150%` recovery visibly map to approximately `1.5`, `2`, `2.5`, and `3` gauge bands respectively.
- [ ] Early-game and endgame battles retain readable gauge variation because each battle freezes its own median normalization scale.
- [ ] Speed buffs and debuffs change the affected actor's future gauge and order without rescaling every other actor.
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
