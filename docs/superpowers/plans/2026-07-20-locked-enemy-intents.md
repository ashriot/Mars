# Locked Enemy Intents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make displayed enemy actions persistent until execution while allowing target-only corrections for Decoy, Taunt, defeat, revival, and other eligibility changes.

**Architecture:** `BattleManager` will separate explicit intent planning from presentation refresh and target revalidation. `EnemyTargetSelector` will expose availability-only legality checks that do not reconsider preference rankings, while `EnemyCard` will preserve its locked action and replace only illegal targets. Intent presentation will flash only when the stored action or targets actually change.

**Tech Stack:** Godot 4.6.3, typed GDScript resources, GUT integration tests.

## Global Constraints

- Preserve existing enemy abilities, rules, priorities, cooldowns, and authored selectors.
- HP, Guard, Focus, CT, turn-order, and ordinary condition changes cannot replace a locked ability or rule.
- `is_untargetable` and `is_taunting` remain the universal condition flags for target eligibility.
- Breach remains the sole state-driven action replacement and produces Recover.
- Every automated Godot run uses an isolated `HOME`.

---

### Task 1: Availability-Only Target Revalidation

**Files:**
- Modify: `src/scripts/enemies/enemy_target_selector.gd`
- Modify: `src/battle/enemy_card.gd`
- Test: `test/integration/test_enemy_ai_intents.gd`

**Interfaces:**
- Produces: `EnemyTargetSelector.targets_are_legal(enemy: EnemyCard, targets: Array[ActorCard], context: EnemyAIContext) -> bool`.
- Produces: `EnemyCard.revalidate_intent_targets(context: EnemyAIContext) -> bool`, returning whether the displayed target list changed.
- Consumes: the locked `EnemyDecision.rule.selector`, current AI context, `is_untargetable()`, `is_taunting()`, and defeat state.

- [ ] **Step 1: Write failing Decoy, Taunt, and inert-condition tests**

Add integration tests that plan one hostile action, then apply a condition to the relevant hero:

```gdscript
func test_decoy_retargets_locked_action_without_replanning() -> void:
	var fixture := _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	var locked_action := fixture.enemy.intended_action
	var original_target := fixture.enemy.intended_targets[0] as HeroCard
	var decoy := Condition.new()
	decoy.condition_name = "Decoy"
	decoy.is_untargetable = true
	await original_target.add_condition(decoy)
	assert_eq(fixture.enemy.intended_action, locked_action)
	assert_ne(fixture.enemy.intended_targets, [original_target])
	assert_eq(fixture.enemy.intent_decision_count, 1)
	_free_fixture(fixture)

func test_taunt_redirects_locked_action_without_replanning() -> void:
	var fixture := _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	var locked_action := fixture.enemy.intended_action
	var original_target := fixture.enemy.intended_targets[0] as HeroCard
	var taunter: HeroCard = fixture.sands if original_target == fixture.echo else fixture.echo
	var draw_fire := Condition.new()
	draw_fire.condition_name = "Draw Fire"
	draw_fire.is_taunting = true
	await taunter.add_condition(draw_fire)
	assert_eq(fixture.enemy.intended_action, locked_action)
	assert_eq(fixture.enemy.intended_targets, [taunter])
	assert_eq(fixture.enemy.intent_decision_count, 1)
	_free_fixture(fixture)

func test_ordinary_condition_does_not_change_locked_targets() -> void:
	var fixture := _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	var locked_action := fixture.enemy.intended_action
	var locked_targets := fixture.enemy.intended_targets.duplicate()
	var buff := Condition.new()
	buff.condition_name = "Ordinary Buff"
	await fixture.echo.add_condition(buff)
	assert_eq(fixture.enemy.intended_action, locked_action)
	assert_eq(fixture.enemy.intended_targets, locked_targets)
	assert_eq(fixture.enemy.intent_decision_count, 1)
	_free_fixture(fixture)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
env HOME=/tmp/mars-locked-intents-red-1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_ai_intents -gexit
```

Expected: the new tests fail because condition changes currently replan every enemy and no target-only revalidation API exists.

- [ ] **Step 3: Add selector legality and target-only replacement**

Refactor selector candidate construction into shared helpers and add an availability-only check:

```gdscript
func targets_are_legal(enemy: EnemyCard, targets: Array[ActorCard],
	context: EnemyAIContext) -> bool:
	var heroes := _eligible_heroes(context)
	var allies := _eligible_allies(enemy, context)
	match type:
		Type.SELF:
			return targets == [enemy]
		Type.ALL_HEROES, Type.VALID_HERO_CANDIDATES:
			return _same_actor_set(targets, heroes)
		Type.ALL_ALLIES:
			return _same_actor_set(targets, allies)
		Type.SEEDED_HERO, Type.PREFERRED_CONDITION_HERO, \
			Type.HIGHEST_FOCUS_HERO, Type.HIGHEST_GUARD_HERO, \
			Type.LOWEST_GUARD_HERO, Type.HERO_CLOSEST_TO_ACTING:
			return targets.size() == 1 and targets[0] in heroes
		Type.LOWEST_HP_PERCENT_ALLY, Type.LEAST_GUARD_ALLY, \
			Type.ALLY_FURTHEST_FROM_ACTING:
			return targets.size() == 1 and targets[0] in allies
	return false
```

The hostile eligible-hero helper filters defeated and untargetable heroes and narrows applicable selector types to living taunters. `EnemyCard.revalidate_intent_targets()` uses this method, reruns only the locked selector when illegal, synchronizes both decision target arrays, and never calls `EnemyDecisionEngine.choose()`.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the command from Step 2. Expected: all `test_enemy_ai_intents.gd` tests pass through the new target-revalidation cases.

- [ ] **Step 5: Commit the target revalidation boundary**

```bash
git add src/scripts/enemies/enemy_target_selector.gd src/battle/enemy_card.gd test/integration/test_enemy_ai_intents.gd
git commit -m "feat: retarget locked enemy intents"
```

### Task 2: Lock Tactical Decisions Across Combat Changes

**Files:**
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/battle/enemy_card.gd`
- Test: `test/integration/test_enemy_ai_intents.gd`

**Interfaces:**
- Consumes: `EnemyCard.revalidate_intent_targets(context)` from Task 1.
- Produces: `_refresh_all_enemy_intent_presentations()` for value-only UI refreshes.
- Produces: `_revalidate_all_enemy_intent_targets()` for condition/death/revival eligibility changes.

- [ ] **Step 1: Replace live-replanning tests with locked-decision tests**

Change the Focus, HP, Guard, and CT tests to assert that automatic signals or `update_turn_order()` leave `intent_decision_count == 1` and preserve the same action and targets. Change execution tests so a now-false tactical condition still executes the stored action, while an illegal defeated target is retargeted without choosing another action:

```gdscript
func test_execution_keeps_cached_action_when_trigger_no_longer_matches() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	var locked_action := fixture.enemy.intended_action
	fixture.echo.current_focus = 0
	await fixture.manager.execute_enemy_turn(fixture.enemy)
	assert_eq(fixture.manager.executed_action, locked_action)
	assert_eq(fixture.enemy.intent_decision_count, 1)
	_free_fixture(fixture)
```

Add a breach assertion proving Recover replaces the locked action, and retain cooldown advancement coverage for planning the next intent after completion.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
env HOME=/tmp/mars-locked-intents-red-2 /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_ai_intents -gexit
```

Expected: signal, turn-order, and execution assertions fail because `BattleManager` still calls `_update_all_enemy_intents()` and rechecks tactical conditions at execution.

- [ ] **Step 3: Separate planning, presentation, and target revalidation**

Make these runtime changes:

```gdscript
func update_turn_order() -> void:
	_publish_turn_order(TurnOrderUpdate.REFRESH)

func _refresh_all_enemy_intent_presentations() -> void:
	for enemy: EnemyCard in get_living_enemies():
		enemy.refresh_intent_presentation()

func _revalidate_all_enemy_intent_targets() -> void:
	var context := _enemy_ai_context()
	for enemy: EnemyCard in get_living_enemies():
		enemy.revalidate_intent_targets(context)
```

HP, Guard, and Focus handlers call presentation refresh only. Condition changes call target revalidation and turn-order publication. Death and revival call target revalidation after the actor-list mutation. Remove the pre-passive spawn planning and the per-turn-boundary global planning calls. Plan all enemies once after initial passive/head-start setup, then plan only the enemy that just completed its activation.

At execution, call target revalidation once. `_is_enemy_decision_executable()` checks the locked action, cooldown readiness, and `targets_are_legal()` but does not recheck rule conditions or compare the selector's preferred output. If still impossible, safely complete the activation without choosing a fallback tactic.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the command from Step 2. Expected: all locked-decision, revalidation, recovery, and cooldown cases pass.

- [ ] **Step 5: Commit the locked planning lifecycle**

```bash
git add src/battle/battle_manager.gd src/battle/enemy_card.gd test/integration/test_enemy_ai_intents.gd
git commit -m "fix: lock telegraphed enemy tactics"
```

### Task 3: Flash Only Genuine Intent Changes

**Files:**
- Modify: `src/battle/enemy_card.gd`
- Test: `test/integration/test_enemy_ai_intents.gd`

**Interfaces:**
- Produces: change-aware intent assignment that compares action identity and ordered target identity before calling `flash_intent()`.
- Consumes: explicit planning and target-only replacement from Tasks 1 and 2.

- [ ] **Step 1: Write failing flash-count tests**

Give the quiet enemy fixture a no-animation `flash_intent()` override that increments a counter. Assert initial planning flashes once, repeated identical explicit planning does not flash again, presentation refresh does not flash, and Decoy retargeting increments the count exactly once.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
env HOME=/tmp/mars-locked-intents-red-3 /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_ai_intents -gexit
```

Expected: repeated identical decisions flash because `_update_intent_ui()` currently always calls `flash_intent()`.

- [ ] **Step 3: Move flashing behind semantic change detection**

Remove flashing from generic UI rendering. Before assigning a decision, compare the previous action and targets; render the latest presentation every time, but call `flash_intent()` only when the action or ordered target identities differ. `clear_intent()` clears without flashing, and presentation-only refresh never flashes.

- [ ] **Step 4: Run focused and production-content verification**

Run:

```bash
env HOME=/tmp/mars-locked-intents-green /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect enemy_ai_intents -gexit
env HOME=/tmp/mars-locked-intents-content /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect damage_content -gexit
```

Expected: both selections pass with no parser errors or unexpected runtime errors.

- [ ] **Step 5: Run the battle lab and full suite**

```bash
env HOME=/tmp/mars-locked-intents-lab /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --quit-after 900 res://src/dev/endgame_battle_lab.tscn
env HOME=/tmp/mars-locked-intents-full /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

Expected: the lab reaches player action with four valid drone intents. The full suite passes except for any explicitly reported expectation mismatch unrelated to this change.

- [ ] **Step 6: Commit the presentation fix**

```bash
git add src/battle/enemy_card.gd test/integration/test_enemy_ai_intents.gd
git commit -m "fix: flash only changed enemy intents"
```
