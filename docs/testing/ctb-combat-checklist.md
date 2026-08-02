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
