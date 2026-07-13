# Controller Navigation Manual Verification

All device checks below are intentionally unchecked until performed on the named physical hardware. Record the date, OS, device/connection, build, and concise pass/fail notes beside each item. A keyboard simulation or automated test is not a hardware pass.

## Test setup

- [ ] Start from a clean test campaign and verify no production save is overwritten.
- [ ] Confirm controller glyph family matches the connected device before beginning.
- [ ] Disconnect and reconnect the active controller on the title screen, in the hub, on the dungeon map, in a terminal modal, during battle action selection, during target selection, and on the result screen; verify focus/cursor and hints recover.
- [ ] Connect two controllers, remove the active one, and verify the remaining controller becomes authoritative without invalid focus.
- [ ] Use an unknown/generic controller through Steam Input and verify the Steam Deck glyph family with an Xbox-compatible button layout and semantic actions.

## Xbox controller

- [ ] Xbox controller (USB): complete the full title → hub → dungeon → terminal → battle → result loop.
- [ ] Xbox controller (Bluetooth/wireless): complete the same loop and hot-plug checks.
- [ ] Verify A confirms, B cancels, X/Y activate their displayed battle skills, bumpers page, triggers switch roles/map zoom where shown, and glyphs match.

## PlayStation controller

- [ ] DualShock/DualSense (USB): complete the full loop.
- [ ] DualShock/DualSense (Bluetooth): complete the full loop and hot-plug checks.
- [ ] Verify Cross confirms, Circle cancels, Square/Triangle activate their displayed battle skills, shoulder/trigger glyphs match, and no Xbox glyphs remain after detection.

### DualSense dungeon scan acceptance

Run this sequence once over USB and once over Bluetooth. Fill in both rows before checking either connection as passed; a keyboard simulation or automated test does not qualify.

| Run | Date | macOS version | Device | Connection | Tested commit | Pass/fail notes |
| --- | --- | --- | --- | --- | --- | --- |
| USB |  |  | PS5 DualSense | USB |  |  |
| Bluetooth |  |  | PS5 DualSense | Bluetooth |  |  |

- [ ] Enter scan targeting and verify the free cursor starts at the party while the hex reticle independently marks the nearest scan center.
- [ ] Hold and rotate the left stick through cardinal and diagonal directions at minimum, middle, and maximum zoom; movement is smooth, continuous, and consistent at every zoom level.
- [ ] Move onto a distant hidden hex and press Cross; the Cross glyph is displayed, the reveal continues while scanner, traversal, and camera input are locked for 0.25 seconds, and the camera remains at the scanned region after the reveal.
- [ ] Immediately after the 0.25-second lock ends, perform ordinary traversal; normal movement and alert interaction resume, and the existing traversal camera behavior recenters or follows the party as designed.
- [ ] Re-enter scan targeting and press Circle to cancel; the Circle glyph is displayed and no scan is performed.
- [ ] Re-enter scan targeting and use the D-pad; each direction moves the free cursor as a digital fallback and the reticle follows the nearest eligible center.
- [ ] At minimum, middle, and maximum zoom, keep the scanner inside the camera dead zone: the central (middle) 60% of the viewport on both axes. Cross each boundary and verify the camera stays still inside, begins following after the boundary is crossed, follows smoothly outside, and does not interrupt scanner movement.
- [ ] With the scanner neutral, manually pan with the right stick; resume left-stick movement and verify the camera smoothly reacquires while right-stick pan does not fight scanner following.
- [ ] Hover or click a hidden scan center with the mouse, then move the left stick; controller mode resumes from the last hovered hex without a cursor jump.
- [ ] Confirm another distant hidden scan and verify input returns after the brief reveal lock while the camera remains at the scanned region.

## Nintendo controller

- [ ] Switch Pro/Joy-Con pair: complete the full loop and hot-plug checks.
- [ ] Verify Nintendo-position confirm/cancel: A/right confirms and B/bottom cancels everywhere, including nested modals and battle targeting.
- [ ] Verify X/Y and shoulder/trigger glyphs and actions match Nintendo labels and positions.

## Steam Deck and Steam Input

- [ ] Steam Deck controls: complete the full loop in Gaming Mode.
- [ ] Steam Input known-device profile: glyph family and every semantic action match the selected layout.
- [ ] Steam Input unknown/generic profile: Steam Deck glyph-family fallback with an Xbox-compatible layout remains usable and internally consistent.
- [ ] At native handheld resolution, cursor, focused-button scaling, button glyphs, hint text, terminal links, skill nodes, map nodes, card targets, and result totals are readable without clipping.

## Mouse and keyboard switching

- [ ] Move the mouse by 1–3 pixels in controller mode; incidental jitter does not steal controller mode or hide controller presentation.
- [ ] Use the keyboard or move the mouse deliberately beyond the jitter threshold; keyboard/mouse mode activates without warping the pointer and hides non-clickable hint-bar text.
- [ ] Alternate mouse movement/click and controller input rapidly at least ten times on every major screen; the latest meaningful input wins and focus/cursor never becomes stale.
- [ ] Switch keyboard → controller → mouse while a modal is open; focus remains trapped inside the top modal.
- [ ] After mouse hover leaves a battle target or dungeon node, controller input restores a valid semantic cursor without selecting anything.

## Title and hub

- [ ] Title: initial focus is visible and enabled; confirm starts/continues only the focused choice; disabled Load is skipped.
- [ ] Hub outer depth: navigate every enabled action, confirm opens the selected panel, and cancel/return behavior is stable.
- [ ] Party hero-list depth: traverse every hero, enter content, return to the remembered hero, and close outward.
- [ ] Skill role/page depth: traverse each unlocked role and every authored page; remembered role, page, and node restore after leaving and returning.
- [ ] Skill node depth: D-pad geometry is deterministic; available, affordable, locked, and owned nodes show the correct cursor/hint state; confirm never purchases twice.
- [ ] L1/R1 page controls wrap only among authored pages; one-page roles omit or disable page hints.
- [ ] L2/R2 role controls remain active at hero, page, and node depths and restore a valid node.
- [ ] Inventory depth: traverse all slots, begin/cancel held-item mode, and verify valid versus invalid equipment/mod targets.
- [ ] Equipment depth: navigate equipment and mod slots, confirm the existing action path, cancel held state before leaving, and never act on an empty/stale hero.
- [ ] Open nested hub/terminal-style modals; directional input and confirm stay in the top modal, cancel closes only the top layer, and the prior focus/hints restore.

## Dungeon map and terminal

- [ ] Slowly rotate the left stick around the current node; the reticle snaps only to eligible adjacent revealed/completed nodes, changes once per clear directional choice, and does not flicker at boundaries.
- [ ] Release the stick; confirmation disables immediately, the reticle returns to the current node, briefly remains visible, and fades out.
- [ ] Hold a direction and tap confirm repeatedly across completed nodes; each move reevaluates from the new node without requiring stick recentering, while new interactions still lock input.
- [ ] Use the controller D-pad as a digital fallback and verify it selects the same eligible destinations.
- [ ] Switch to keyboard-and-mouse mode; WASD/arrows do not preview or move between nodes, while mouse hover/click immediately owns the reticle and traversal.
- [ ] Enter scan targeting with a controller; the free scanner cursor starts at the party while the hex reticle independently marks the nearest scan center.
- [ ] Hold and rotate the left stick through cardinal and diagonal directions; cursor speed is smooth, continuous, zoom-consistent, and requires no confirm presses.
- [ ] Scan a distant hidden hex; confirm uses the displayed family glyph, reveals around that hidden center, briefly locks input, and leaves the camera at the scanned region.
- [ ] Keep the scanner inside the central camera box, then cross each boundary; the camera stays still inside and smoothly follows outside without cutting off scanner input.
- [ ] Manually pan with the right stick while the scanner is neutral; resume left-stick motion and verify the camera smoothly reacquires while right-stick pan cannot fight it.
- [ ] Hover/click hidden scan centers with the mouse, switch back to controller, and verify the free cursor resumes from the last hovered hex without a jump.
- [ ] Verify semantic confirm/cancel and D-pad fallback on the connected controller family.
- [ ] Hold pan in all four directions; movement is smooth, delta-scaled, and clamped.
- [ ] Zoom in/out with L2/R2 or displayed triggers; limits clamp and no input leaks through a locked map/modal.
- [ ] Recenter returns the camera to the current node at minimum, middle, and maximum zoom.
- [ ] Open a terminal from the fixed map path; focus/cursor moves to the terminal, all five links can be selected, and a choice fires once.
- [ ] Terminal cancel/close returns to the live map adapter, prior preview/current node, and correct map hints.

## Battle and result

- [ ] Action 1 activates only the first visible enabled affordable skill.
- [ ] Action 2 activates only the second visible enabled affordable skill.
- [ ] Action 3 activates only the third visible enabled affordable skill.
- [ ] Action 4 activates only the fourth visible enabled affordable skill.
- [ ] Disabled, unaffordable, hidden, and missing skills do nothing and are not advertised as available.
- [ ] Shift activates the currently legal direction once and does nothing when neither direction is legal.
- [ ] Target navigation cycles only living valid targets using screen geometry; cursor and hover presentation agree.
- [ ] Confirm executes through the existing target selection path exactly once.
- [ ] Target cancel executes nothing, exits targeting, and returns cursor/hints to action selection or the active hero region.
- [ ] Open any battle modal/overlay; action, shift, target, confirm, and cancel input cannot leak beneath it; closing restores the battle adapter cursor.
- [ ] Victory, retreat, and defeat result screens each focus Continue, show readable totals, accept confirm once, and route onward once.

## Sign-off

- [ ] Xbox physical hardware passed — device/build/date/notes:
- [ ] PlayStation physical hardware passed — device/build/date/notes:
- [ ] Nintendo physical hardware passed — device/build/date/notes:
- [ ] Steam Deck physical hardware passed — device/build/date/notes:
- [ ] Steam Input generic-controller fallback passed — device/build/date/notes:
- [ ] Mouse/keyboard switching passed — device/build/date/notes:
