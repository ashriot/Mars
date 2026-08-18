# CTB Combat Manual Verification

All checks below are intentionally unchecked until performed interactively in combat. Record the date, OS, input device or connection, resolution, tested commit, and concise pass/fail notes. Automated tests and headless project runs do not count as visual or physical-input acceptance.

## Test setup

- [ ] Launch the project with the isolated test `HOME`, enter a representative combat with multiple heroes and duplicate enemy types, and complete the named `1280x800` and `1920x1080` paths below.
- [ ] Exercise mouse, keyboard, controller, and direct touch input where each check names them; a simulated input family does not count as a physical-device pass.

## Battle combatant foundation regression

Automated evidence recorded on 2026-08-02 with Godot 4.6.3, an isolated test `HOME`, and source commit `04365d656c5d356e29b4534373c57aa3e8a463e3`:

- The second headless import and parse in a clean exact-commit clone exited successfully with only the documented macOS certificate warning and no parser errors.
- Card/combatant binding passed 26/26 tests with 169 assertions. This includes release-safe setup results, exact-model validation, specialized card pairing, ownership/rebinding rejection, off-tree scene validation, and complete encounter rollback.
- Presentation-operation cancellation passed 11/11 tests with 37 assertions. Acting, action-hide, and health waits complete when views are freed, replaced, unregistered, or pruned, including repeated health synchronization.
- The complete clean-clone run passed 951/951 tests with 14705 assertions, and the independent final boundary re-review reported PASS with no findings.
- The complete dirty-workspace run passed 950/951 tests and 14704/14705 assertions. Its sole failure is the intentionally preserved, unrelated `src/dev/endgame_battle_lab.tscn` HP-multiplier edit: the dirty scene contains `1.0` while the committed scene and test expect `5.0`.

Automated coverage does not establish the following visual or physical-input behavior. Leave every item unchecked until it is performed interactively against the recorded commit.

### Controller-only current 2D presentation

- [ ] Complete a representative battle using only a controller. Use face buttons to choose skills; traverse, confirm, and cancel targets; inspect intent and conditions; and verify damage, Guard, Breach, defeat, revival, and CTB progression remain correct and readable.
- [ ] Confirm hero and enemy card focus, target availability, selection, acting state, and action affordability remain visually distinct through the complete controller loop.

### Mouse current 2D presentation

- [ ] Complete a representative battle with mouse input. Hover and click through every valid target, inspect intent and conditions, cancel and retarget actions, and verify damage, Guard, Breach, defeat, revival, and CTB progression remain correct and readable.
- [ ] Confirm hover transitions and target presentation do not leave stale highlights, stale intent, or mismatched card state after the pointer moves between combatants and action controls.

## First-person 3D battle slice

Automated evidence renewed on 2026-08-02 for exact reviewed source commit `1c245d6e32cd199e45e47a56dc3566128669a821` with Godot `4.7.1.stable.official.a13da4feb` at `/Applications/Godot 4.7.app/Contents/MacOS/Godot` and an isolated test `HOME` for every run:

- The working checkout imported successfully with no script, parser, resource, or load errors. Twenty focused suites covering the optional local model loader, shared shake setting, W/M formations, 3D world and projected HUD, EyeDrone presentation, combatant binding, controller navigation, responsive layout, controller-playable loop, presentation cancellation, CTB ownership, camera rig, projectile layer, theme bootstrap, actor-card tooltip and target presentation, damage feedback, duplicate-enemy identity, and actor queue passed 290/290 tests with 1,841 assertions.
- The complete working-checkout run passed 1,061/1,062 tests and 15,980/15,981 assertions across 82 scripts. Its sole failure was the intentionally preserved, unrelated `src/dev/endgame_battle_lab.tscn` HP-multiplier edit: the dirty scene contains `1.0` while the committed source and test expect `5.0`.
- A shared clone detached at the exact source commit began without `.godot/` or `assets/graphics/models/quaternius_local/`. Its first cacheless and second cached Godot 4.7.1 editor imports both exited zero with no script, parser, resource, or load errors; only the documented macOS certificate diagnostic appeared. The asset-free full suite then passed 1,062/1,062 tests with 15,974 assertions across 82 scripts.
- The final independent whole-branch review of this exact source reported PASS with no findings.
- The working checkout has 33 curated Quaternius source/license files plus 22 local Godot `.import` sidecars (55 files total). The whole local-model root is ignored, the representative EyeDrone path is covered by `.gitignore`, and no Quaternius vendor file is tracked.
- Interactive acceptance is intended for physical `1280x800` and `1920x1080` windows with the local assets installed. No interactive visual or physical-input path was performed for this record: mouse/keyboard, controller, direct touch, Steam Deck hardware, and iPhone remain unverified.

### Industrial room rebuild acceptance — 2026-08-02

Accepted interactively on macOS with Godot `4.7.1`, mouse/keyboard inspection, and local Quaternius assets installed. The tested visual-candidate commit was `54b552ea65dc9c47e56f860b3cbcf3a4451ac57a`.

- [x] At `1920x1080`, the repaired live room was accepted as enclosed and substantially improved: repeated bays provide depth, the local modules do not visibly clip, the sealed bulkhead anchors the back wall, five enemies and projected HUDs remain readable, and the hero/action UI remains legible. Repaired screenshot: `/var/folders/4z/yt0cvhrd7xs5zb13m1d00wf80000gn/T/codex-clipboard-f201d43d-d76e-4247-aca4-e6003e887e68.png`.
- [x] At `1280x800`, the repaired live runtime was inspected and explicitly accepted in text as “it looks fine.” No new repaired screenshot was retained. The earlier screenshot at `/var/folders/4z/yt0cvhrd7xs5zb13m1d00wf80000gn/T/codex-clipboard-43f034eb-4e18-427c-8316-de38e11e08d1.png` confirms the 16:10 room and UI layout only; it predates the decal-cache repair and does not prove the final local door import.
- [x] The repaired `1280x800` live launch spawned the encounter and all seven combatants with zero matching `T_Decals`, missing dependency, `Door_Frame_A`, `Door_Metal`, or optional-door fallback errors. The remaining auto-quit RenderingServer/RID shutdown diagnostics were not accompanied by a runtime texture artifact.
- [x] Fresh isolated verification after the cache repair: editor import exited `0`; `test_battle_world_3d` passed 11/11 tests with 213 assertions; `test_battle_formation_layout` passed 4/4 tests with 15 assertions; the complete suite passed 1,067/1,067 tests with 16,149 assertions across 82 scripts.

The user separately observed that the existing hero/action UI covers too much of the screen and leaves the enemies sitting too far behind it. That concern is explicitly deferred as outside this industrial-room rebuild; this acceptance did not change the UI, battle camera, enemy staging, or scene presentation contracts. Controller, direct-touch, Steam Deck hardware, iPhone, and broader combat-loop items below remain unchecked unless separately performed.

Headless automation does not establish any item below. Keep each item unchecked until the named visual or physical-input path is performed and record the date, OS/device, input device or connection, physical resolution, and tested commit.

### Readable enemy HUD and formation — pending hands-on acceptance

Run every item at physical `1920x1080` and the desktop-proxy `1280x800` window. Steam Deck hardware acceptance remains distinct from the desktop proxy and is still pending.

- [ ] Verify W and M five-enemy encounters retain correct model/HUD attribution and visibly distinct depth rows.
- [ ] Verify compact enemy HUDs do not overlap, including long intent text, `23/30` Guard, conditions, safe-edge clamping, and one open detail block.
- [ ] Verify every enemy HP bar is `220x32`, permanently displays centered `current / max` text, and keeps rounded pink actual health over yellow delayed damage or green delayed healing.
- [ ] Verify inspected name, centered intent, defenses, exact HP, Guard, `VULNERABLE`, and `BREACHED` remain readable over both bright walls and dark room regions at physical `1920x1080` and desktop-proxy `1280x800`.
- [ ] Damage each outer, inner, and center enemy with kinetic, energy, piercing, rapid, and critical hits; verify each value appears over the struck model center with the established color and critical `!`, while rapid values remain distinguishable.
- [ ] Verify inspection details open above the persistent compact HUD with a visible gap and do not obscure another compact HUD.
- [ ] Verify delayed damage is yellow and delayed healing is green on enemies and on every hero/actor card.
- [ ] Verify mouse model clicking and green valid-target outlines; then verify controller selection/inspection and unchanged face-button skill selection.
- [ ] Verify Idle motion continues uninterrupted after enemy attacks and hits.
- [ ] Verify no regression to room lighting, ceiling practicals, model readability, action-bar behavior, hero-card height, or Exo 2 typography.

### Room, formation, and projected HUD

- [ ] At physical `1280x800`, verify room scale, camera height, full background coverage, lighting, and readable separation between the first-person scene and hero UI.
- [ ] At physical `1920x1080`, repeat the room/background check and confirm the established combat UI remains readable, unclipped, and balanced around the 3D view.
- [ ] Confirm every active EyeDrone body sits clearly above the hero-card band and remains visually connected to its overhead Intent/Guard/HP stack in both front and back rows.
- [ ] Confirm the center of the battlefield reads as a physical dark-metal room rather than a black void: drone surfaces, wall structure, and floor depth remain visible while blue practical lights retain contrast.
- [ ] Exercise encounters with one through five enemies, including both W and M layouts, and verify overlap, depth, target clarity, and the large-boss center-three layout with one ally on each side.
- [ ] Verify projected enemy information remains anchored and safely clamped: intent above Guard/HP, condition icons below, hover reveal with mouse, controller reveal for the selected target, and correct teardown after defeat or replacement.

### Motion, feedback, and presentation lifecycle

- [ ] With physical mouse input, verify edge-look is subtle and bounded, returns cleanly toward center, never drifts the selected target, and does not move while controller/focus presentation owns input.
- [ ] Verify the EyeDrone visibly reaches Idle, Charging, Attack, Hit, defeat, and return-to-Idle states without stale HUD, model, or animation state.
- [ ] Compare camera and hero-panel shake at `0%`, the default setting, an intermediate setting, and `100%`; confirm zero is truly still and intermediate feedback scales proportionally without obscuring combat information.
- [ ] Verify each enemy laser begins at the visible attacker, ends at the intended hero panel, renders above the world without covering essential UI, completes cleanly, and produces hero-panel plus camera impact feedback exactly once.

### Physical controller and input ownership

- [ ] At `1280x800`, complete a representative battle using only a physical controller: select skills with face buttons, traverse targets directionally, confirm and cancel, reveal enemy details, and verify focus never becomes ambiguous.
- [ ] At `1920x1080`, repeat a short controller regression and verify directional targeting remains deterministic across overlapping W/M enemies.
- [ ] Scroll the CTB rail with the physical controller right stick during targeting and ordinary combat; confirm the rail moves while the camera and selected target remain unchanged.
- [ ] Repeat the full controller-only battle path on Steam Deck hardware at native `1280x800`; a desktop-sized proxy does not satisfy this item.

### Godot 4.7 visual compatibility

- [ ] Re-run iPhone visual acceptance on Godot 4.7.1; the prior Godot 4.6.3 device result does not establish this pass.
- [ ] Inspect CTB gauge antialias appearance at both intended desktop resolutions because Godot 4.7 changed CanvasItem line-antialias feathering.
- [ ] Open representative combat and UI scenes in the Godot 4.7.1 editor and verify fallback-font previews remain legible before runtime theme hydration, while the running game uses the authored Oxanium fonts.
- [ ] Exercise direct touch only if touch play remains supported, recording the physical device and noting any projected-HUD, targeting, CTB-scroll, or camera-ownership conflicts.

## Damage architecture acceptance

Record the viewport, input method, tested commit, and concise observed values for each check.

- [ ] Confirm Kinetic and Energy hits remove Guard and can cause Breach; confirm the hit that causes Breach receives the OVR bonus.
- [ ] Confirm intrinsic Piercing and Targeting-Laser-converted Piercing bypass Defense without removing Guard or causing Breach.
- [ ] Trigger a critical hit and confirm its popup reflects PRE and the resolved damage type.
- [ ] Use Focused Bolt at multiple remaining-Focus values and confirm its preview and executed damage follow 20% power plus 20% per remaining Focus after paying its cost.
- [ ] Use Mind Storm and confirm its preview uses remaining Focus after paying its cost.
- [ ] Use Rapid Fire where a target dies during the action and confirm later hits retain the original fixed damage distribution.
- [ ] For the same target state, confirm enemy intent and action tooltip numbers match observed noncritical damage.
- [ ] Use lifedrain against a target with less HP than the attempted damage and confirm healing uses actual HP removed, excluding overkill.

## Cooldown enemy AI acceptance

Observe a current multi-action enemy across at least four of its own turns. Restart the encounter and repeat state changes where required; record the encounter seed, enemy type, authored cooldown gaps, and observed intent sequence.

- [ ] Restart with the same seed and confirm the enemy's opening intent is identical.
- [ ] Confirm cooldown abilities do not repeat before their authored turn gap.
- [ ] Change Taunt or Breach while an intent is visible and confirm the intent updates without advancing any cooldown.
- [ ] Observe duplicate enemies and confirm each keeps independent cooldown state.
- [ ] For every observed intent, confirm its visible damage still matches the executed action.

## Enemy combat primitives acceptance

Record the combatants, resources, conditions, role transition, visible intent or tooltip values, executed values, and tested commit.

- [ ] Use an enemy action whose damage scales from the target's Focus or Guard and confirm its intent, tooltip detail, and executed damage all use that exact target resource value.
- [ ] Heal a living enemy and confirm it gains HP without hero Focus scaling; target a defeated enemy with a non-revive heal and confirm it remains defeated at zero HP.
- [ ] Cleanse one of two active debuffs and confirm only the selected debuff is removed, its own removal reaction fires once, and the other debuff remains active.
- [ ] Shift into a role with a Shift action and an `AFTER_SHIFT_ACTION` damage reaction; confirm the role changes first, the new role's Shift action resolves next, and the reaction damage occurs exactly once afterward.

## Responsive controller-only acceptance

Record the date, OS/device, controller and connection, physical resolution, tested commit, and concise notes. Keep desktop-proxy and Steam Deck hardware results separate.

### Full `1280x800` desktop-proxy path

- [ ] Set the physical game window to `1280x800`, enter representative combat using only the controller, and verify the battlefield background covers 16:10; actor cards, status effects, action controls, hints, and the CTB rail are readable, unclipped, and do not overlap.
- [ ] Activate each of the four visible action slots when legal, cancel back out, and verify disabled/unaffordable states, glyphs, recovery values, focus, and compact action sizing remain clear. Open tooltips from controls and targets near every viewport edge and verify each tooltip stays fully visible with readable text.
- [ ] For hero and enemy single-target actions, traverse every valid target, cancel, restore focus, and confirm a target. Verify availability outlines, breathing selection glow, acting gold, and target-dependent CTB preview remain distinct and no target card falls outside the viewport.
- [ ] Scroll the CTB rail from top to bottom and back with the controller. Verify the active entry, all twenty projected turns, role icons/enemy abbreviations, gauges, scrollbar, and overflow indication remain readable and contained; scrolling must not change the chosen action or target.
- [ ] Observe preview reorder and preview-clear animations at multiple rail scroll positions, then commit an action. Verify preview movement preserves scroll, committed advance resets it, reorder/acting animations remain visually contained, the consumed entry exits intentionally, and no card becomes clipped or stranded.
- [ ] Observe victory, retreat, and defeat result transitions where available. Verify the combat UI clears cleanly, the transition covers the full viewport, result text/totals and Continue focus are readable and in bounds, and confirm routes onward exactly once.

### Short `1920x1080` desktop regression

- [ ] At a physical `1920x1080` window, enter representative combat using only the controller; activate one action, traverse and cancel targets, inspect an edge tooltip, and verify established desktop actor/action/rail spacing and focus remain intact.
- [ ] Scroll the CTB rail to its end, observe one preview reorder/clear cycle and one committed acting transition, then reach one result transition. Verify at least eight complete future cards are exposed initially, all twenty remain inspectable, and no desktop animation or transition regresses.

### Steam Deck hardware acceptance

- [ ] On Steam Deck, verify an exported build launches borderless at native `1280x800`, then repeat the full controller-only combat path. Record physical text/glyph readability, actionable control size, scroll feel, targeting clarity, and animation issues; a desktop-proxy result is not a hardware pass.

## Queue rail layout

- [ ] The unified rounded rail is black at 90% opacity and keeps icons/text readable over bright combat backgrounds.
- [ ] Hero queue interiors are fully opaque dark cyan and enemy interiors are fully opaque dark magenta, with no battlefield art showing through.
- [ ] Non-current gauges use one bright cyan or magenta readiness arc over the dark-gray track, with no shade layers, nested lines, separators, or pips.
- [ ] The arc begins at top-center and fills clockwise as a turn approaches.
- [ ] The acting battlefield card uses the exact queue gold for the full hero or enemy turn.
- [ ] Target availability, selection outline, and pulse remain independently visible while the acting gold outline persists beneath them.
- [ ] Every queue entry is a uniform `72x72` square, and only the current entry has a gold perimeter.
- [ ] Hero entries use their authored role icon and role color; enemy entries use readable Oxanium abbreviations in magenta.
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
