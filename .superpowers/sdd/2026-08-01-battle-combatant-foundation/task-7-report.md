# Task 7 — Combatant-authoritative battle orchestration

Commit: `41e5a74` (`refactor: make battle manager combatant authoritative`)

## Implementation

- Made `BattleManager.actor_list`, `current_actor`, action execution, targeting, CTB projection, queue entries, and battle result checks authoritative on `BattleCombatant`, `HeroCombatant`, and `EnemyCombatant` identities.
- Added a dedicated `BattleScene/Combatants` root. The manager now creates models there, creates existing cards separately under the UI areas, binds each card to its model, and registers the card presentation against the model.
- Added the manager presentation registry and routed target state, acting state, action labels, health synchronization, intent refresh, pointer input, and target geometry through `CombatantPresentation`.
- Retyped `BattleScene` current target, navigation origin, and remembered faction targets to combatants. Controller and pointer selection now retain model identity while reading visibility and screen geometry from the registered presentation.
- Retyped `ActionBar`, `ActionButton`, `CTBSimulator`, `TurnQueue`, and `ActorQueue` to combatant identities while preserving the direct face-button and trigger mappings.
- Narrowed the remaining Task 6 action, effect, condition, trait, damage, preview, and description seams from the temporary `Node` bridge to combatants, then deleted `BattleCombatant.resolve_model` and its migration helpers.
- Kept defeat and revival presentation-safe: defeat removes a combatant from the live roster without unregistering its view, and revival restores the combatant in stable `battle_priority` order.
- Preserved enemy intent planning, locked target identity, execution, and presentation through combatants.
- Updated battle, controller, CTB, revival, AI, damage, responsive-layout, and game-manager fixtures to assert model authority without changing the current 2D visual layout.

## TDD evidence

1. Added the manager registry and target-identity regression before migrating production targeting.
   - RED: `BattleScene._set_current_target` still required an `ActorCard`, so passing the bound `EnemyCombatant` failed at the old signature.
   - GREEN: target selection retained the exact combatant and obtained geometry, visibility, and target state through its registered presentation.
2. Migrated manager spawning, CTB, queue, action bar, and action execution together so no mixed card/model authority remained between those boundaries.
   - Focused fixtures exposed stale card arrays and card-typed overrides during the migration; each was narrowed to the corresponding combatant type rather than adding compatibility translation.
3. Added stable revival ordering after model-owned roster removal.
   - Review RED: the first insertion rule put a revived equal-priority combatant after the wrong peers.
   - GREEN: revival inserts by immutable `battle_priority`, preserving deterministic faction order and preventing duplicate roster entries.
4. Added presentation replacement coverage before finalizing registry signal routing.
   - RED: replacing a registered presentation left outgoing target state/input ownership active.
   - GREEN: the outgoing view returns to neutral, its input handlers disconnect, and the replacement receives the semantic target state.
5. Removed the temporary domain bridge only after the manager and every gameplay caller passed combatants directly.

## Original final verification

Every Godot invocation used `HOME=/tmp/mars-godot-home` and Godot 4.6.3.

- `actor_card_target_presentation`: 8/8 passing, 61 assertions.
- `battle_combatant`: 15/15 passing, 49 assertions.
- `battle_condition_targets`: 19/19 passing, 42 assertions.
- `ctb_action_content`: 4/4 passing, 20 assertions.
- `damage_hit_plan`: 4/4 passing, 7 assertions.
- `damage_preview`: 39/39 passing, 165 assertions.
- `damage_effect_execution`: 46/46 passing, 193 assertions.
- `damage_content`: 46/46 passing, 1,572 assertions.
- `ctb_simulator`: 19/19 passing, 52 assertions.
- `turn_queue`: 19/19 passing, 112 assertions.
- `battle_controller_navigation`: 56/56 passing, 269 assertions.
- `controller_playable_loop`: 2/2 passing, 104 assertions.
- `battle_revival`: 6/6 passing, 27 assertions.
- `enemy_ai_intents`: 21/21 passing, 68 assertions.
- `battle_responsive_layout`: 2/2 passing, 12 assertions.
- `game_manager_interactions`: 33/33 passing, 188 assertions.
- Headless editor parse (`--editor --quit`): exit 0 with no parser errors.
- Complete GUT suite: 892/893 passing, 14,331/14,332 assertions across 68 scripts.
- The sole full-suite failure was the known unrelated dirty lab-scene expectation: the preserved scene contains `enemy_hp_multiplier = 1.0`, while `test_endgame_battle_lab` expects `5.0` (6/7 tests, 176/177 assertions).
- The required `resolve_model`/temporary-`Node` signature scan returned no matches.
- The required card-class scan across the action, condition, trait, damage, and action-data gameplay boundary returned no matches.

The recurring macOS certificate-store diagnostic and documented successful-exit ObjectDB/resource diagnostics were unchanged.

## Original files changed

- `src/battle/action_bar.gd`
- `src/battle/action_button.gd`
- `src/battle/actor_card.gd`
- `src/battle/actor_queue.gd`
- `src/battle/battle_manager.gd`
- `src/battle/battle_scene.gd`
- `src/battle/battle_scene.tscn`
- `src/battle/combatants/battle_combatant.gd`
- `src/battle/combatants/hero_combatant.gd`
- `src/battle/ctb_simulator.gd`
- `src/battle/damage/damage_context.gd`
- `src/battle/damage/damage_hit_plan.gd`
- `src/battle/damage/damage_preview.gd`
- `src/battle/hero_card.gd`
- `src/battle/presentation/card_combatant_presentation.gd`
- `src/battle/presentation/combatant_presentation.gd`
- `src/battle/turn_queue.gd`
- `src/scripts/action_effects/action_effect.gd`
- `src/scripts/action_effects/effect_apply_condition.gd`
- `src/scripts/action_effects/effect_damage.gd`
- `src/scripts/action_effects/effect_damage_inversion.gd`
- `src/scripts/action_effects/effect_healing.gd`
- `src/scripts/action_effects/effect_modify_ct.gd`
- `src/scripts/action_effects/effect_modify_focus.gd`
- `src/scripts/action_effects/effect_modify_guard.gd`
- `src/scripts/action_effects/effect_modify_stat.gd`
- `src/scripts/action_effects/effect_recover_breach.gd`
- `src/scripts/action_effects/effect_remove_condition.gd`
- `src/scripts/action_effects/effect_remove_debuffs.gd`
- `src/scripts/action_effects/effect_swap_resources.gd`
- `src/scripts/action_effects/pre_hit_effect.gd`
- `src/scripts/action_effects/pre_hit_effect_modify_attacker_stats.gd`
- `src/scripts/conditions/condition.gd`
- `src/scripts/conditions/condition_scale_with_debuffs.gd`
- `src/scripts/conditions/condition_source_power_bonus.gd`
- `src/scripts/data/action.gd`
- `src/scripts/enemies/enemy_ai_context.gd`
- `src/scripts/equipment/trait.gd`
- `test/integration/test_battle_controller_navigation.gd`
- `test/integration/test_battle_responsive_layout.gd`
- `test/integration/test_battle_revival.gd`
- `test/integration/test_controller_playable_loop.gd`
- `test/integration/test_damage_content.gd`
- `test/integration/test_endgame_battle_lab.gd`
- `test/integration/test_enemy_ai_intents.gd`
- `test/integration/test_game_manager_interactions.gd`
- `test/integration/test_turn_queue.gd`
- `test/unit/test_actor_card_target_presentation.gd`
- `test/unit/test_battle_combatant.gd`
- `test/unit/test_battle_condition_targets.gd`
- `test/unit/test_ctb_action_content.gd`
- `test/unit/test_ctb_simulator.gd`
- `test/unit/test_damage_effect_execution.gd`
- `test/unit/test_damage_hit_plan.gd`
- `test/unit/test_damage_preview.gd`

The unrelated user edit in `src/dev/endgame_battle_lab.tscn` was preserved and excluded from the commit.

## Original self-review and concerns

- Confirmed cards remain presentation-only consumers and combatants remain the sole gameplay identities through spawning, action execution, targeting, CTB, queueing, AI, defeat, and revival.
- Confirmed pointer input crosses the presentation boundary only through typed semantic signals and controller input remains direct and focus-free.
- Confirmed target navigation uses registered presentation geometry but preserves combatant target memory and deterministic combatant ordering.
- Confirmed defeated combatants retain presentations for animation and legal revival.
- Confirmed no temporary `resolve_model` or gameplay-domain card bridge remained.
- No interactive visual or physical-controller acceptance was performed. Automated controller-loop and responsive-layout coverage remained green, and this task intentionally retained the current 2D presentation.

## Fix Round 1

Commit: recorded separately from the original Task 7 commit.

### Findings addressed

- Reordered hero turn startup so `HeroCombatant.on_turn_started()` resets shift state and completes turn-start triggers before `ActionBar.load_actions()` reads shift availability. Returning heroes now rearm both shift controls.
- Removed the duplicate hero presentation deactivation from `_finish_hero_turn`; `find_and_start_next_turn` is the single handoff owner.
- Removed `hero_area`/`enemy_area` guards from enemy intent planning and target revalidation. Both operations now use model-owned roster state in headless managers; only intent rendering remains presentation-gated.
- Added semantic `acting` state to `CombatantPresentation`. Replacing a live presentation transfers target and acting state exactly once, neutralizes the old presentation, disconnects its handlers, and does not publish a false target invalidation.
- Hardened registry lifecycle handling for explicit unregister, valid replacement, presentation tree exit, combatant tree exit, already-freed off-tree objects, and manager teardown.
- Made invalidation reentrant-safe by erasing registry state before `target_invalidated` callbacks run. `BattleScene` now clears current target, navigation origin, and remembered faction target through the existing invalidation signal when a selected presentation disappears.
- Preserved model authority when only a presentation disappears: a live combatant stays in the turn roster and remains tracked for later model cleanup.
- Ensured repeated unregister emits one invalidation only and all presentation input/lifecycle handlers are disconnected at their ownership boundary.
- Typed the combatant-only collections in `_apply_target_presentation`, `get_targets`, action preview primary targets, `Effect_Damage._build_hit_plan`, and `EnemyCombatant._targets_match`. Typed-array callers now explicitly use `Array[BattleCombatant]` to respect GDScript array invariance.

### TDD and review evidence

1. Shift controls after a later turn:
   - RED: `battle_controller_navigation` was 56/57 passing with 270/273 assertions; both shift buttons stayed disabled and the left-shift signal did not emit.
   - GREEN after turn-start-before-action-load ordering: 57/57 passing, 273 assertions.
2. Exactly-once hero deactivation:
   - RED: `ctb_simulator` was 19/20 passing with 52/53 assertions; the presentation recorded `[false, false, true]` instead of `[false, true]`.
   - GREEN after removing the duplicate call: 20/20 passing, 53 assertions.
3. Model-only enemy intent planning and revalidation:
   - RED: `enemy_ai_intents` was 21/23 passing with 68/71 assertions; headless planning produced no intent/targets and revalidation retained a defeated target.
   - Intermediate GREEN: planning passed while revalidation remained RED at 22/23.
   - GREEN after removing both presentation-area guards: 23/23 passing, 71 assertions.
4. Acting-state replacement:
   - RED: `battle_controller_navigation` was 57/58 passing with 273/277 assertions; the old view received no deactivation and the replacement received no activation.
   - GREEN: the old view records exactly `[false]`, the replacement exactly `[true]`, and both asynchronous visual states settle correctly.
5. Registry lifetime and invalidation were developed through focused mutations:
   - RED unregister behavior: 58/59 passing, 278/282 assertions; target invalidation and `BattleScene` memory clearing were absent.
   - RED stale off-tree presentation lookup: 59/60 passing, 283/285 assertions; lookup attempted a freed-object cast.
   - RED independently freed presentation: 60/61 passing, 284/288 assertions; registry and selected-target memory remained stale.
   - RED independently freed combatant: 61/62 passing, 291/297 assertions; roster, registry, presentation state, handlers, and invalidation were not cleaned.
   - RED stale off-tree combatant enumeration: 62/63 passing, 298/305 assertions; enumeration reached a freed cast and retained stale state/callbacks.
   - RED repeated unregister: 63/64 passing, 312/313 assertions; invalidation emitted twice.
   - RED reentrancy mutation: 63/64 passing, 313/314 assertions; the invalidation callback still observed the stale registry entry.
   - GREEN after registry cleanup: 64/64 passing, 314 assertions.
6. Strict typing verification exposed invariant-array callers:
   - RED: `battle_controller_navigation` was 63/64 passing with 309/310 assertions, and `controller_playable_loop` failed to parse because `Array[EnemyCombatant]` cannot be passed as `Array[BattleCombatant]`.
   - GREEN after declaring the callers' semantic collections as `Array[BattleCombatant]`: 64/64 passing (314 assertions) and 2/2 passing (104 assertions).
7. Completion self-review added a live-model preservation mutation:
   - RED: `battle_controller_navigation` was 63/64 passing with 314/315 assertions because fallback cleanup removed the valid model when only its off-tree presentation had been freed.
   - GREEN: losing the view preserves the roster model and its exit tracking; later fallback cleanup removes the freed model and callback. Final navigation result: 64/64 passing, 318 assertions.

### Fix Round 1 final verification

Every Godot invocation used `HOME=/tmp/mars-godot-home` and Godot 4.6.3.

- Headless editor parse (`--editor --quit`): exit 0 with no parser errors.
- `ctb_simulator`: 20/20 passing, 53 assertions.
- `turn_queue`: 19/19 passing, 112 assertions.
- `battle_controller_navigation`: 64/64 passing, 318 assertions.
- `controller_playable_loop`: 2/2 passing, 104 assertions.
- `battle_revival`: 6/6 passing, 27 assertions.
- `enemy_ai_intents`: 23/23 passing, 71 assertions.
- `battle_responsive_layout`: 2/2 passing, 12 assertions.
- `game_manager_interactions`: 33/33 passing, 188 assertions.
- `actor_card_target_presentation`: 8/8 passing, 61 assertions.
- `battle_combatant`: 15/15 passing, 49 assertions.
- `battle_condition_targets`: 19/19 passing, 42 assertions.
- `ctb_action_content`: 4/4 passing, 20 assertions.
- `damage_hit_plan`: 4/4 passing, 7 assertions.
- `damage_preview`: 39/39 passing, 165 assertions.
- `damage_effect_execution`: 46/46 passing, 193 assertions.
- `damage_content`: 46/46 passing, 1,572 assertions.
- `endgame_battle_lab`: 6/7 passing, 176/177 assertions; the sole failure remains the preserved user scene's `1.0` multiplier versus the committed test's `5.0` expectation.
- Complete GUT suite: 903/904 passing, 14,384/14,385 assertions across 68 scripts. The sole failure is the same unrelated dirty lab scene.
- Discovery audit: the repository contains exactly 68 `test_*.gd` files and GUT discovered exactly 68 scripts. No `pending`, `skip`, `should_skip_script`, or `should_skip_test` markers were found.
- Full-run hazard scan found no parser errors, unexpected test errors, skipped tests, or pending tests.
- The required `resolve_model`/temporary-`Node` signature scan returned no matches.
- The required card-class scan across action/effect/condition/trait/damage/action-data gameplay code returned no matches.
- The reviewed combatant-array scan confirms typed target parameters and locals; no untyped `targets`, `parent_targets`, or `other_targets` declarations remain at those boundaries.

The recurring macOS certificate-store warning, the three expected ignored-inner-class warnings, and documented shutdown resource diagnostics were unchanged.

### Fix Round 1 files changed

- `src/battle/battle_manager.gd`
- `src/battle/combatants/enemy_combatant.gd`
- `src/battle/presentation/card_combatant_presentation.gd`
- `src/battle/presentation/combatant_presentation.gd`
- `src/scripts/action_effects/effect_damage.gd`
- `test/integration/test_battle_controller_navigation.gd`
- `test/integration/test_controller_playable_loop.gd`
- `test/integration/test_enemy_ai_intents.gd`
- `test/unit/test_ctb_simulator.gd`

The unrelated user edit in `src/dev/endgame_battle_lab.tscn` was preserved and will remain excluded from the fix commit.

### Fix Round 1 self-review and remaining concerns

- Confirmed shift rearming occurs before action UI availability is read and turn-start triggers remain awaited.
- Confirmed one handoff owner deactivates the outgoing hero and activates the next actor.
- Confirmed AI planning and revalidation use only combatant state; the remaining area guard protects rendering only.
- Confirmed presentation replacement transfers semantic target and acting states without invalidation, and unregister/freed-object cleanup invalidates only after registry removal.
- Confirmed presentation exit does not remove a live model from turn authority, while combatant exit removes roster, current-actor, pending-shift, registry, target memory, and handler state.
- Confirmed deterministic roster ordering and revival behavior remain covered by the existing CTB/revival suites.
- Confirmed the preserved dirty lab scene was not edited, restored, staged, or committed.
- No interactive visual or physical-controller acceptance was performed. The changes are orchestration and lifecycle foundations; the automated controller loop and responsive battle layout remain green.

## Fix Round 2

Commit: recorded separately from the original Task 7 and Fix Round 1 commits.

### Findings addressed

- Moved combatant lifetime ownership out of `register_presentation` and into `_connect_combatant_signals`. A headless model is now tracked even when it has no view, while losing only a presentation never detaches the model from battle authority.
- Added symmetrical combatant teardown for HP, guard, conditions, defeat, revival, hero focus, and tree-exit callbacks. Removing a valid model also clears the manager back-reference, roster, pending-shift owner, and presentation registration, so a detached defeated model cannot revive back into the battle.
- Made active-actor removal an atomic cancellation boundary. Target state, focused action, current/executing action, recovery snapshot, action panel, ActionBar hero ownership, pending shift state, and current actor are cleared synchronously; the manager enters `LOADING` without advancing the turn.
- Added a safe fallback for an already-freed off-tree active model. Fallback cancellation runs only when pruning actually removed an invalid authoritative combatant, avoiding changes to intentionally actorless managers.
- Added explicit ActionBar hero release, including both focus and presentation-event callbacks, and manager-teardown coverage for those closures.
- Kept targeting cancellation available after the final valid target presentation disappears. Controller cancel and pressing the selected face button both release the action, while invalidating one target with alternatives available preserves the selection and moves to a legal presentation.
- Explicitly typed every remaining production target-array local returned by `BattleManager.get_targets` or `EnemyTargetSelector.select`, including manager action execution/description paths, enemy planning/revalidation, and triggered action effects.

### TDD and mutation evidence

1. Presentation-independent lifecycle ownership:
   - RED: `battle_controller_navigation` was 64/66 passing with 323/333 assertions. A detached valid defeated hero retained all manager callbacks and its `battle_manager` reference, revived back into the roster, and a headless model had no tree-exit tracking.
   - GREEN: 66/66 passing, 333 assertions. Model teardown disconnects the complete manager callback inventory and headless cleanup removes roster/pending state without requiring a presentation.
2. Active actor removal:
   - RED: 66/67 passing with 334/348 assertions. Current/focused/executing state, recovery, panel, ActionBar ownership, and targeting survived removal; subsequent face-button and shift input produced invalid `current_focus` and `shift_role` accesses.
   - GREEN: 67/67 passing, 347 assertions, with no engine errors after action, cancel, and shift input.
3. Final-target invalidation:
   - RED: 68/70 passing with 357/361 assertions. Both controller cancel and the selected face button left the action and focus latched after the final target view disappeared; the alternative-target preservation case already passed.
   - GREEN: 70/70 passing, 361 assertions. Both cancellation paths release cleanly and the alternative-target case remains selected.
4. Completion self-review added off-tree-current and manager-teardown ownership cases:
   - RED: 69/71 passing with eight failing assertions. The freed off-tree current model retained action/execution/recovery/state, and manager teardown retained ActionBar hero ownership plus two hero callbacks.
   - Mutation checks rejected two overly broad fallbacks: one recursed through presentation pruning, and one canceled intentionally actorless test managers. The final fallback is reentrancy-safe and requires an invalid authoritative combatant to have actually been pruned.
   - GREEN: `battle_controller_navigation` 71/71 passing, 377 assertions.

### Fix Round 2 final verification

Every Godot invocation used `HOME=/tmp/mars-godot-home` and Godot 4.6.3.

- Headless editor parse (`--editor --quit`): exit 0 with no parser errors.
- `battle_controller_navigation`: 71/71 passing, 377 assertions.
- `enemy_ai_intents`: 23/23 passing, 71 assertions.
- Complete GUT suite: 910/911 passing, 14,443/14,444 assertions across 68 scripts. The sole failure remains the unrelated preserved dirty lab scene: its `enemy_hp_multiplier` is `1.0`, while `test_endgame_battle_lab` expects `5.0`.
- Target-array audit: no untyped production local remains for a `get_targets` or `selector.select` result. The only similarly named inferred local is `preview_targets`, which is a dictionary mapping live to preview combatants rather than a target array.
- `git diff --check`: clean.

The recurring macOS certificate-store warning, the three expected ignored-inner-class warnings, and documented shutdown resource diagnostics were unchanged.

### Fix Round 2 files changed

- `src/battle/action_bar.gd`
- `src/battle/battle_manager.gd`
- `src/battle/battle_scene.gd`
- `src/battle/combatants/enemy_combatant.gd`
- `src/scripts/action_effects/effect_damage.gd`
- `src/scripts/action_effects/effect_modify_focus.gd`
- `src/scripts/action_effects/effect_recover_breach.gd`
- `src/scripts/enemies/enemy_decision_engine.gd`
- `test/integration/test_battle_controller_navigation.gd`

The unrelated user edit in `src/dev/endgame_battle_lab.tscn` was preserved and will remain excluded from the fix commit.

### Fix Round 2 self-review and remaining concerns

- Confirmed lifecycle authority follows model registration, not view registration: presentation replacement/removal does not affect the roster, while model removal disconnects the complete callback inventory and clears manager ownership.
- Confirmed active-actor teardown is synchronous, does not call `find_and_start_next_turn`, and leaves later controller action/cancel/shift input safe in `LOADING` unless the battle was already over.
- Confirmed manager exit releases ActionBar hero callbacks even when the hero model remains valid outside the manager subtree.
- Confirmed final-target invalidation preserves an available alternative and otherwise retains enough selection state for either controller cancellation path to work.
- Confirmed the preserved dirty lab scene was not edited, restored, staged, or committed.
- No interactive visual or physical-controller acceptance was performed. This round changes lifecycle, input-safety, and typing foundations without changing the current 2D presentation.
