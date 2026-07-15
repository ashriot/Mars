# Combat Target Final Fix Report

Date: 2026-07-15

## Scope

Resolved all five Important findings from the whole-feature review of `abd8cd9..cdeaf74`. The implementation is limited to combat target preview/ownership/invalidation behavior and focused integration coverage.

## Finding 1: group PARENT CT preview

Root cause: `BattleManager.preview_action_turn_order()` treated a null `selected_target` as an empty PARENT target set and skipped default-PARENT `Effect_ModifyCT` effects. Group actions deliberately pass null because they have no single selected parent, even though their primary target set is already resolved by `action.target_type`.

Regression: `test_group_parent_ct_preview_projects_every_affected_actor()` exercises the production preview simulator and emitted projected queue. With an `ALL_ENEMIES` action and a default-PARENT 50% CT effect, both enemies must appear at 25 projected ticks and live CT must be restored afterward.

Fix: resolve preview primary targets from `action.target_type` for classified group actions, retain the selected actor for single-target actions, and omit PARENT effects only when neither source exists. Target-side resolution now correctly uses `actor is HeroCard` rather than the previously always-true `actor is ActorCard` expression.

RED: focused battle navigation exited 1; both affected actors projected at 50 ticks instead of 25.

GREEN: both affected actors project at 25 ticks through the emitted production queue, with live CT restored.

## Finding 2: cancel stale CTB preview

Root cause: `cancel_targeting()` called `_clear_current_target(false)` while `manager.current_action` was still live. That helper republished the outgoing action preview (including SELF/action-wide CT effects), then cancel nulled the action without requesting the ordinary projection.

Regression: `test_cancel_suppresses_action_preview_and_restores_ordinary_turn_order()` selects an action with a SELF CT effect and records the action-preview and ordinary-update boundaries.

Fix: null the action before clearing target ownership, then explicitly call `update_turn_order()` after normal targeting cleanup/state restoration.

RED: outgoing action preview count was 1 instead of 0; ordinary projection count was 0 instead of 1.

GREEN: outgoing action preview count is 0; ordinary projection count is exactly 1.

## Finding 3: non-controller action replacement

Root cause: `_on_action_selected()` only scheduled a deferred targeting refresh. If the old visible target was valid for the replacement action, refresh retained it, violating mouse/keyboard empty-entry ownership.

Regression: `test_keyboard_action_replacement_synchronously_clears_shared_target()` replaces an action after selecting a target valid for both and asserts immediately at the action-selection signal boundary.

Fix: on action selection, synchronously clear current target and navigation origin whenever active ownership is not controller, then keep the existing deferred refresh. Controller restoration/memory behavior is unchanged.

RED: both `_current_target` and `_navigation_origin` retained the old enemy.

GREEN: both are null synchronously after replacement.

## Finding 4: hidden target candidates

Root cause: `_valid_targets()` filtered target flag and defeat state but not `is_visible_in_tree()`, so hidden cards participated in remembered restoration, fallback, and directional navigation.

Regressions:

- `test_hidden_remembered_target_uses_visible_controller_fallback()`
- `test_hidden_first_candidate_is_excluded_from_controller_fallback()`

Fix: require every valid target candidate to be visible in the scene tree. All restoration, fallback, confirmation, and navigation paths share this candidate source.

RED: the hidden remembered card and hidden first candidate were each selected.

GREEN: both cases select the visible fallback.

## Finding 5: death invalidation relay

Root cause: actor death normalized the dead card and removed it from `actor_list`, but no event told `BattleScene` to reconcile current target, retained origin, or side memory. State changed only after unrelated refreshes.

Regressions:

- `test_real_death_path_immediately_restores_controller_fallback()` calls the real `ActorCard.defeated()` signal path and expects immediate controller fallback plus updated origin/memory.
- `test_real_death_path_immediately_clears_pointer_target_origin_and_memory()` calls the same real path and expects immediate mouse/pointer clearing.

Fix: `BattleManager` emits `target_invalidated(actor)` immediately after removal. `BattleScene` clears matching origin/memory and synchronously refreshes targeting, which applies the existing controller fallback or pointer-clear policy and refreshes CTB preview.

RED: controller current/origin/memory all retained the dead enemy; pointer current/origin/memory also retained it.

GREEN: controller immediately selects the second enemy and pointer immediately clears all three references.

## RED/GREEN evidence

Command used for both RED and GREEN:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_controller_navigation -gexit
```

- RED: exit 1; 35/42 tests passed, 7 failed, 149/163 assertions passed. Failures mapped exactly to the five findings above; no parser or fixture errors remained.
- GREEN: exit 0; 42/42 tests passed, 163 assertions.

## Additional focused verification

- `-gselect actor_card_target_presentation -gexit`: 2/2 tests, 28 assertions, exit 0.
- `-gselect controller_playable_loop -gexit`: 2/2 tests, 93 assertions, exit 0.
- `-gselect navigation_ux_layer -gexit`: 30/30 tests, 138 assertions, exit 0.
- `-gselect input_manager -gexit`: 35/35 tests, 183 assertions, exit 0.

## Final verification

- Godot import: `HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit` — exit 0; no parser errors.
- Complete GUT suite: exit 0; 36 scripts, 448/448 tests, 9,562 assertions.
- `git diff --check` — exit 0, no output.
- Precise removed-symbol grep:

  ```sh
  rg -n '\b(start_flashing|stop_flashing|TargetFlash|blink_tween|start_blinking|stop_blinking)\b' src/battle test --glob '*.gd' --glob '*.tscn'
  ```

  Exit 1 with no matches. The intentionally retained action-bar methods `start_flashing_panel()` and `stop_flashing_panel()` are distinct and unrelated to actor-card targeting or hero blinking.

## Files

- `src/battle/battle_manager.gd`
- `src/battle/battle_scene.gd`
- `test/integration/test_battle_controller_navigation.gd`
- `.superpowers/sdd/combat-target-final-fix-report.md`

No Godot sidecars were generated or changed.

## Self-review

- The group preview change resolves primary targets once per action and preserves null-selected behavior for single-target actions, so pointer empty-entry still omits target-dependent PARENT effects while SELF/action-wide effects remain eligible.
- Cancel now suppresses only the outgoing action preview and restores ordinary CTB exactly once.
- Non-controller clearing is synchronous at the existing action-selection signal seam; controller code paths are untouched and existing memory tests remain green.
- Visibility is enforced at the shared candidate source rather than separately in navigation/restoration branches.
- Death notification occurs after normalization/removal and before the first await, giving the scene a coherent immediate view of living targets.
- Scope excludes hub/hint UI, cursor ownership, hardware warp, scan cursor, save behavior, balance, and AI execution.

## Concerns and remaining manual checks

- No unresolved implementation concerns.
- The documented macOS CA-certificate warning and expected engine shutdown leak diagnostics appeared on some successful runs; there were no parser errors, crashes, or unexpected test failures.
- Physical/visual manual acceptance (outline brightness, pulse readability, rapid device handoffs, and real controller feel) was not performed in this headless pass and remains covered by `docs/testing/controller-manual-checklist.md`.
