# Controller Navigation Manual Verification

All device checks below are intentionally unchecked until performed on the named physical hardware. Record the date, OS, device/connection, build, and concise pass/fail notes beside each item. A keyboard simulation or automated test is not a hardware pass.

## Test setup

- [ ] Start from a clean test campaign and verify no production save is overwritten.
- [ ] Confirm controller glyph family matches the connected device before beginning.
- [ ] Disconnect and reconnect the active controller on the title screen, in the hub, on the dungeon map, in a terminal modal, during battle action selection, during target selection, and on the result screen; verify focus/cursor and hints recover.
- [ ] Connect two controllers, remove the active one, and verify the remaining controller becomes authoritative without invalid focus.
- [ ] Use an unknown/generic controller through Steam Input and verify the Steam Deck glyph family with an Xbox-compatible button layout and semantic actions.

## Focus and pointer ownership

- [ ] Ordinary controller navigation hides the hardware arrow and shows no snapped cursor on focused buttons.
- [ ] Focused buttons and button-like controls use the clear 70% neutral fill with readable dark foregrounds across title orange, hub blue, terminal, and result palettes.
- [ ] Focus clears without scaling or tweening, and every authored style and foreground color is restored exactly.
- [ ] Mouse motion in controller mode changes neither ownership nor visible focus; the first click reveals the independent pointer and activates nothing, while the matching release is also consumed and the second click activates exactly once.
- [ ] Mouse motion in keyboard-and-mouse mode hides visible focus but retains its logical origin; mouse hover is temporary visual ownership and does not replace that origin. The first arrow/WASD press restores the retained focus without moving and the second moves.
- [ ] Any keyboard input after controller presentation reveals the hardware pointer and performs its action; keyboard direction moves immediately.
- [ ] Controller direction after pointer presentation hides the pointer and moves immediately; keyboard direction after controller presentation reveals the pointer and moves immediately.
- [ ] Battle uses actor highlighting and dungeon traversal uses its reticle without an ordinary navigation arrow.
- [ ] Security scanning alone shows the controller-positioned software pointer while the hardware pointer remains hidden and physically independent.

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

- [ ] Move the left stick partially and fully: the world aim follows analog magnitude, the map moves at a consistent speed, and the cursor stays centered while the camera is attached; D-pad provides the same movement at full digital magnitude.
- [ ] During controller scanning, the reticle snaps through real hexes beneath the centered scan software pointer while the OS mouse remains at its independent physical position.
- [ ] Move the physical mouse without clicking: controller ownership, scan software pointer, and reticle remain authoritative. The first mouse-button transaction activates nothing, hides the software pointer, and reveals the OS cursor at its independent physical position; a second click activates exactly once.
- [ ] Release the left stick or D-pad: the world aim and attached camera stop immediately with no drift or acceleration.
- [ ] With left input neutral, hold the right stick: the camera detaches and pans while the cursor and reticle remain anchored to the same world target and move together on screen.
- [ ] Resume left-stick or D-pad input after panning: left input wins, the camera slides back to the world aim without warping it, then keeps the cursor centered again.
- [ ] Confirm after hovering a distant hex: the last hovered hex is scanned, the reveal begins, input briefly locks, then the camera smoothly returns to the party.
- [ ] Cancel after hovering a distant hex: no scan is consumed and the camera smoothly returns to the party immediately.

## Nintendo controller

- [ ] Switch Pro/Joy-Con pair: complete the full loop and hot-plug checks.
- [ ] Verify Nintendo-position confirm/cancel: A/right confirms and B/bottom cancels everywhere, including nested modals and battle targeting.
- [ ] Verify X/Y and shoulder/trigger glyphs and actions match Nintendo labels and positions.

## Steam Deck and Steam Input

- [ ] Steam Deck controls: complete the full loop in Gaming Mode.
- [ ] Steam Input known-device profile: glyph family and every semantic action match the selected layout.
- [ ] Steam Input unknown/generic profile: Steam Deck glyph-family fallback with an Xbox-compatible layout remains usable and internally consistent.
- [ ] At native handheld resolution, the 70% neutral focus fill, button glyphs, hint text, protocol rows, skill nodes, map nodes, card targets, and result totals are readable without clipping.

## Mouse and keyboard switching

- [ ] Move the physical mouse by both small and large amounts in controller mode without clicking; motion never changes input ownership, reveals the hardware pointer, changes visible focus, or moves a scan software pointer.
- [ ] Click a physical mouse button; keyboard-and-mouse mode activates, non-clickable hint-bar text hides, the complete first press/release transaction activates nothing, and the OS pointer remains at its independent physical position. A second click activates exactly once.
- [ ] Use each keyboard input category from controller mode; keyboard-and-mouse ownership activates, the hardware pointer appears without moving, and the key's confirm, cancel, shortcut, or directional action proceeds immediately.
- [ ] Alternate physical mouse clicks, keyboard input, and controller input rapidly at least ten times on every major screen; the latest activating input wins and focus/cursor never becomes stale.
- [ ] Switch keyboard → controller → physical mouse click while a modal is open; focus remains trapped inside the top modal.
- [ ] After keyboard-and-mouse mode is activated by a click and mouse hover leaves a battle target or dungeon node, controller input immediately restores a valid reticle or actor highlight without selecting anything.

## Title and hub

- [ ] Title: initial focus is visible and enabled; confirm starts/continues only the focused choice; disabled Load is skipped.
- [ ] Hub outer depth: navigate every enabled action, confirm opens the selected panel, and cancel/return behavior is stable.
- [ ] Party hero-list depth: traverse every hero, enter content, return to the remembered hero, and close outward.
- [ ] Skill role/page depth: traverse each unlocked role and every authored page; remembered role, page, and node restore after leaving and returning.
- [ ] Skill node depth: D-pad geometry is deterministic; available, affordable, locked, and owned nodes show the correct focus/hint state; confirm never purchases twice.
- [ ] L1/R1 page controls wrap only among authored pages; one-page roles omit or disable page hints.
- [ ] L2/R2 role controls remain active at hero, page, and node depths and restore a valid node.
- [ ] Inventory depth: traverse all slots, begin/cancel held-item mode, and verify valid versus invalid equipment/mod targets.
- [ ] Equipment depth: navigate equipment and mod slots, confirm the existing action path, cancel held state before leaving, and never act on an empty/stale hero.
- [ ] Open nested hub/terminal-style modals; directional input and confirm stay in the top modal, cancel closes only the top layer, and the prior focus/hints restore.

## Dungeon map and terminal

- [ ] Slowly rotate the left stick around the current node; the reticle snaps only to eligible adjacent hidden/revealed/completed nodes, changes once per clear directional choice, and does not flicker at boundaries.
- [ ] Release the stick; confirmation disables immediately, the reticle returns to the current node, briefly remains visible, and fades out.
- [ ] Hold a direction and tap confirm repeatedly across completed nodes; each move reevaluates from the new node without requiring stick recentering, while new interactions still lock input.
- [ ] Use the controller D-pad as a digital fallback and verify it selects the same eligible destinations.
- [ ] Switch to keyboard-and-mouse mode with a physical mouse click; WASD/arrows do not preview or move between nodes, while subsequent mouse hover/click owns the reticle and traversal.
- [ ] Move the left stick partially and fully: the world aim follows analog magnitude, the map moves at a consistent speed, and the cursor stays centered while the camera is attached; D-pad provides the same movement at full digital magnitude.
- [ ] During controller scanning, the reticle snaps through real hexes beneath the centered scan software pointer while the OS mouse remains at its independent physical position.
- [ ] Move the physical mouse without clicking: controller ownership, scan software pointer, and reticle remain authoritative. Click once: the complete transaction activates nothing, the software pointer hides, and the OS cursor appears at its independent physical position; click again to activate exactly once.
- [ ] Release the left stick or D-pad: the world aim and attached camera stop immediately with no drift or acceleration.
- [ ] With left input neutral, hold the right stick: the camera detaches and pans while the cursor and reticle remain anchored to the same world target and move together on screen.
- [ ] Resume left-stick or D-pad input after panning: left input wins, the camera slides back to the world aim without warping it, then keeps the cursor centered again.
- [ ] Confirm after hovering a distant hex: the last hovered hex is scanned, the reveal begins, input briefly locks, then the camera smoothly returns to the party.
- [ ] Cancel after hovering a distant hex: no scan is consumed and the camera smoothly returns to the party immediately.
- [ ] Verify semantic confirm/cancel and D-pad fallback on the connected controller family.
- [ ] Hold pan in all four directions; movement is smooth, delta-scaled, and clamped.
- [ ] Zoom in/out with L2/R2 or displayed triggers; limits clamp and no input leaks through a locked map/modal.
- [ ] Recenter returns the camera to the current node at minimum, middle, and maximum zoom.
- [ ] At 1200×800 and 1280×800, the terminal is centered and only as tall as its header, five rows, and footer; there is no large blank region below Extraction.
- [ ] Protocol titles are orange, outcomes remain white, and every keyboard/controller glyph retains its natural proportions.
- [ ] The footer shows Escape/Circle/B as `EXIT TERMINAL`; using it closes the terminal, while the header X remains clickable.
- [ ] Row order and shortcuts are Security 1/A, Medical 2/X, Finance 3/Y, Scan 4/L1, and Extraction 5/R1.
- [ ] On the normal protocol list, Up/Down and WASD do not highlight or move among rows; no protocol row owns GUI focus.
- [ ] Hover each protocol with the mouse: its caret appears only while hovered, and clicking it activates that row exactly once.
- [ ] On DualSense, Cross, Square, Triangle, L1, and R1 activate only their displayed protocols regardless of prior mouse hover; Circle closes.
- [ ] Press a protocol shortcut during the brief typing animation: it is ignored without skipping or committing; after typing completes, one press activates it.
- [ ] From the ready protocol list, press L1: the terminal overlay and modal are fully gone before the scan cursor and reticle become interactive; no terminal focus, hints, or input interception remains over the map.
- [ ] Cancel scan with Circle: exactly one fresh terminal reopens and becomes ready after its normal short typing animation, with no duplicate or ghost terminal; the scan cursor is gone and OS/custom cursor visibility matches the active input mode.
- [ ] On keyboard, verify 1–4 execute the same protocols and 5 only opens extraction confirmation.
- [ ] Verify Circle always closes/backs out in the normal terminal, R1 opens extraction confirmation, Cross confirms Tactical Retreat exactly once, and Circle returns to the protocol list from confirmation without closing or consuming the terminal.
- [ ] With a mouse, click protocols 1–4 directly; click Extraction, then use its explicit Confirm and Cancel controls.
- [ ] Switch between controller and keyboard-and-mouse while the terminal is open; every embedded glyph updates immediately and the global passive hint bar remains hidden.

## Battle and result

- [ ] Action 1 activates only the first visible enabled affordable skill.
- [ ] Action 2 activates only the second visible enabled affordable skill.
- [ ] Action 3 activates only the third visible enabled affordable skill.
- [ ] Action 4 activates only the fourth visible enabled affordable skill.
- [ ] Disabled, unaffordable, hidden, and missing skills do nothing and are not advertised as available.
- [ ] Shift activates the currently legal direction once and does nothing when neither direction is legal.
- [ ] Target navigation cycles only living valid targets using screen geometry; actor-card highlighting agrees with the selected target and no ordinary navigation arrow appears.
- [ ] Confirm executes through the existing target selection path exactly once.
- [ ] Target cancel executes nothing, exits targeting, and returns highlighting/hints to action selection or the active hero region.
- [ ] Open any battle modal/overlay; action, shift, target, confirm, and cancel input cannot leak beneath it; closing restores the battle adapter highlight.
- [ ] Victory, retreat, and defeat result screens each focus Continue, show readable totals, accept confirm once, and route onward once.

## Sign-off

The controls hint-bar redesign remains deferred. A future pass should make it a deliberate floating panel, use Archivo for sentence-case informational copy, and reserve monospace typography for uppercase labels and other all-caps interface text.

- [ ] Xbox physical hardware passed — device/build/date/notes:
- [ ] PlayStation physical hardware passed — device/build/date/notes:
- [ ] Nintendo physical hardware passed — device/build/date/notes:
- [ ] Steam Deck physical hardware passed — device/build/date/notes:
- [ ] Steam Input generic-controller fallback passed — device/build/date/notes:
- [ ] Mouse/keyboard switching passed — device/build/date/notes:
