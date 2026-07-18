# Enemy Combat Primitives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend shared combat effects to support target Focus/Guard scaling, enemy healing, exact-once condition removal, and reactions after a completed Shift action.

**Architecture:** Existing damage scaling gains an explicit attacker/target owner with attacker as the default. Healing accepts any living `ActorCard` while retaining hero-only Focus behavior. Condition removal is centralized around one condition instance, and a new trigger appended to the enum distinguishes immediate role change from completion of the new role's Shift action.

**Tech Stack:** Godot 4.6.3, typed GDScript, shared damage resolver/presentation, Conditions/Triggers, GUT 9.6.1.

## Global Constraints

- Execute this plan after the enemy cooldown-AI foundation; both plans touch `BattleManager`, and this plan expects the new intent refresh path.
- Use Godot 4.6.3 and isolated `HOME=/tmp/mars-godot-home` for every automated run.
- Preserve all current hero damage and condition semantics unless an explicit test in this plan changes them.
- Append trigger enum values; never insert them between serialized existing values.
- Runtime, preview, tooltip, and enemy intent must consume the same contextual damage calculation.
- Do not author benchmark enemy skills in this plan.

---

### Task 1: Attacker/Target Resource Scaling

**Files:**
- Modify: `src/battle/damage/damage_scaling_flat_per_resource.gd`
- Modify: `src/battle/damage/damage_scaling_base_per_resource.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`
- Modify: `test/unit/test_damage_scaling_rules.gd`
- Modify: `test/unit/test_damage_preview.gd`

**Interfaces:**
- Produces: `ResourceOwner { ATTACKER, TARGET }` on both resource-scaling rules.
- Preserves: existing resources default to `ATTACKER`.
- Produces contribution sources `target_focus` and `target_guard` for target-owned rules.

- [ ] **Step 1: Write failing target-resource tests**

Add to `test_damage_scaling_rules.gd`:

```gdscript
func test_flat_rule_can_read_target_focus_without_changing_attacker_default() -> void:
	var attacker := CombatantSnapshot.new(100, 2, 3, false, false, [])
	var target := CombatantSnapshot.new(100, 5, 7, false, false, [])
	var context := DamageContext.new(attacker, target, 0, 0, null, null, {})
	var attacker_rule := DamageScalingFlatPerResource.new()
	attacker_rule.resource = DamageScalingFlatPerResource.ResourceType.FOCUS
	attacker_rule.potency_per_point = 0.15
	var target_rule := DamageScalingFlatPerResource.new()
	target_rule.resource_owner = DamageScalingFlatPerResource.ResourceOwner.TARGET
	target_rule.resource = DamageScalingFlatPerResource.ResourceType.FOCUS
	target_rule.potency_per_point = 0.15
	assert_almost_eq(attacker_rule.resolve(0.3, context).amount, 0.3, 0.0001)
	assert_eq(attacker_rule.resolve(0.3, context).source, &"remaining_focus")
	assert_almost_eq(target_rule.resolve(0.3, context).amount, 0.75, 0.0001)
	assert_eq(target_rule.resolve(0.3, context).source, &"target_focus")

func test_base_rule_can_read_target_guard() -> void:
	var attacker := CombatantSnapshot.new(100, 0, 1, false, false, [])
	var target := CombatantSnapshot.new(100, 0, 6, false, false, [])
	var context := DamageContext.new(attacker, target, 0, 0, null, null, {})
	var rule := DamageScalingBasePerResource.new()
	rule.resource_owner = DamageScalingBasePerResource.ResourceOwner.TARGET
	rule.resource = DamageScalingBasePerResource.ResourceType.GUARD
	rule.base_scalar_per_point = 0.25
	assert_almost_eq(rule.resolve(1.0, context).amount, 1.5, 0.0001)
	assert_eq(rule.resolve(1.0, context).source, &"target_guard")
```

Add a preview assertion that a `30% ATK + 15% per target Focus` effect at five target Focus resolves to `105% ATK` and its detail text contains `target Focus: 75% potency`.

- [ ] **Step 2: Run focused tests and verify missing owner failures**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "damage_scaling_rules|damage_preview" -gexit
```

Expected: nonzero exit because `ResourceOwner` and `resource_owner` are undefined.

- [ ] **Step 3: Generalize both scaling rules**

In each rule add:

```gdscript
enum ResourceOwner { ATTACKER, TARGET }
@export var resource_owner: ResourceOwner = ResourceOwner.ATTACKER
```

Resolve the selected snapshot and source explicitly:

```gdscript
func _combatant(context: DamageContext) -> CombatantSnapshot:
	return context.target if resource_owner == ResourceOwner.TARGET else context.attacker

func _resource_value(context: DamageContext) -> int:
	var combatant := _combatant(context)
	if combatant == null: return 0
	return combatant.current_focus if resource == ResourceType.FOCUS else combatant.current_guard

func _source() -> StringName:
	if resource_owner == ResourceOwner.TARGET:
		return &"target_focus" if resource == ResourceType.FOCUS else &"target_guard"
	return &"remaining_focus" if resource == ResourceType.FOCUS else &"current_guard"
```

Keep each class's existing scalar calculation unchanged.

- [ ] **Step 4: Add precise presentation labels**

Extend `Effect_Damage._get_contribution_label()`:

```gdscript
&"target_focus": return "target Focus"
&"target_guard": return "target Guard"
```

Do not change existing `remaining_focus` or `current_guard` copy.

- [ ] **Step 5: Run damage architecture coverage and commit**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "damage_scaling_rules|damage_preview|damage_effect_execution|damage_content" -gexit
git diff --check
```

Expected: all selected suites pass.

```sh
git add src/battle/damage/damage_scaling_flat_per_resource.gd src/battle/damage/damage_scaling_base_per_resource.gd src/scripts/action_effects/effect_damage.gd test/unit/test_damage_scaling_rules.gd test/unit/test_damage_preview.gd
git commit -m "feat: scale damage from target resources"
```

---

### Task 2: Healing Any Living Actor

**Files:**
- Modify: `src/scripts/action_effects/effect_healing.gd`
- Modify: `test/unit/test_battle_condition_targets.gd`
- Modify: `test/integration/test_battle_revival.gd`

**Interfaces:**
- Produces: `Effect_Healing` accepts living hero or enemy targets.
- Preserves: revive behavior only when `is_revive` is true.
- Preserves: `focus_scalar` reads target Focus only for `HeroCard`.

- [ ] **Step 1: Replace the old non-hero rejection test with failing enemy-healing cases**

```gdscript
func test_healing_effect_heals_living_enemy_without_hero_focus_scaling() -> void:
	var manager := CapturingBattleManager.new()
	var attacker := EnemyCard.new(); attacker.current_stats = ActorStats.new(); attacker.current_stats.psyche = 20
	var target := EnemyCard.new(); target.current_stats = ActorStats.new(); target.current_stats.max_hp = 100
	target.current_hp = 25; target.is_defeated = false
	var effect := Effect_Healing.new(); effect.potency = 1.5; effect.focus_scalar = 1.0; effect.is_revive = false
	await effect.execute(attacker, [target], manager)
	assert_eq(target.current_hp, 55)
	manager.free(); attacker.free(); target.free()

func test_non_revive_enemy_heal_ignores_defeated_target() -> void:
	var manager := CapturingBattleManager.new()
	var attacker := EnemyCard.new(); attacker.current_stats = ActorStats.new(); attacker.current_stats.psyche = 20
	var target := EnemyCard.new(); target.current_stats = ActorStats.new(); target.current_stats.max_hp = 100
	target.current_hp = 0; target.is_defeated = true
	var effect := Effect_Healing.new(); effect.potency = 2.0; effect.is_revive = false
	await effect.execute(attacker, [target], manager)
	assert_eq(target.current_hp, 0)
	assert_true(target.is_defeated)
	manager.free(); attacker.free(); target.free()
```

- [ ] **Step 2: Run and verify the living-enemy case fails**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "battle_condition_targets|battle_revival" -gexit
```

Expected: living enemy remains at 25 HP.

- [ ] **Step 3: Generalize the target loop**

Replace the `HeroCard` cast gate with:

```gdscript
for target in parent_targets:
	var actor_target := target as ActorCard
	if actor_target == null or not is_instance_valid(actor_target): continue
	if actor_target.is_defeated and not is_revive: continue
	var base_power := attacker.get_power(power_type)
	var scalar := 1.0
	if scales_with_missing_hp:
		var hp_percent := float(actor_target.current_hp) / maxf(actor_target.current_stats.max_hp, 1)
		scalar += 1.0 - hp_percent
	if focus_scalar != 0.0 and actor_target is HeroCard:
		scalar += focus_scalar * (actor_target as HeroCard).current_focus
	actor_target.take_healing(roundi(base_power * potency * scalar), is_revive)
```

Retain waits, diagnostic logging, and empty-target behavior.

- [ ] **Step 4: Run focused healing/revival tests and commit**

Run the Step 2 command. Expected: all selected suites pass.

```sh
git add src/scripts/action_effects/effect_healing.gd test/unit/test_battle_condition_targets.gd test/integration/test_battle_revival.gd
git commit -m "feat: allow effects to heal enemy actors"
```

---

### Task 3: Exact-Once Condition Removal

**Files:**
- Modify: `src/battle/actor_card.gd`
- Modify: `src/scripts/action_effects/effect_remove_condition.gd`
- Modify: `src/scripts/action_effects/effect_remove_debuffs.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`
- Modify: `test/unit/test_battle_condition_targets.gd`
- Modify: `test/unit/test_ctb_simulator.gd`

**Interfaces:**
- Changes: `ActorCard.remove_condition(condition_name: String, report_missing: bool = true) -> bool` becomes awaitable.
- Changes: `ActorCard.remove_debuffs(quantity: int) -> int` becomes awaitable.
- Produces: `_remove_condition_instance(condition: Condition) -> bool` and `_execute_condition_triggers(condition: Condition, event_type: Trigger.TriggerType, context: Dictionary) -> void` private helpers.

- [ ] **Step 1: Write failing exact-removal tests**

Add a recording effect and protect these cases:

```gdscript
func test_removing_one_condition_fires_only_its_on_removed_effect_once() -> void:
	var fixture := _condition_fixture()
	var removed_log: Array[String] = []
	fixture.actor.active_conditions = [
		_condition_with_removed_effect("First", removed_log),
		_condition_with_removed_effect("Second", removed_log),
	]
	var removed := await fixture.actor.remove_condition("First")
	assert_true(removed)
	assert_eq(removed_log, ["First"])
	assert_false(fixture.actor.has_condition("First"))
	assert_true(fixture.actor.has_condition("Second"))
	_free_condition_fixture(fixture)

func test_remove_on_event_runs_event_effect_then_own_removal_once() -> void:
	var fixture := _condition_fixture()
	var log: Array[String] = []
	var condition := _condition_with_event_and_removed_effect("Bomb", Trigger.TriggerType.ON_SHIFT, log)
	condition.remove_on_triggers = [Trigger.TriggerType.ON_SHIFT]
	fixture.actor.active_conditions = [condition]
	await fixture.actor._fire_condition_event(Trigger.TriggerType.ON_SHIFT)
	assert_eq(log, ["shift:Bomb", "removed:Bomb"])
	assert_false(fixture.actor.has_condition("Bomb"))
	_free_condition_fixture(fixture)

func test_remove_debuffs_returns_exact_removed_count() -> void:
	var fixture := _condition_fixture()
	fixture.actor.active_conditions = [_debuff("A"), _debuff("B"), _buff("C")]
	var removed_count := await fixture.actor.remove_debuffs(1)
	assert_eq(removed_count, 1)
	assert_eq(fixture.actor.count_debuffs(), 1)
	assert_true(fixture.actor.has_condition("C"))
	_free_condition_fixture(fixture)
```

- [ ] **Step 2: Run and confirm cross-condition ON_REMOVED failure**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "battle_condition_targets|ctb_simulator" -gexit
```

Expected: the first test records unrelated removal effects or the expected awaitable signatures are missing.

- [ ] **Step 3: Centralize trigger execution and removal ownership**

Refactor `ActorCard` to iterate a defensive condition copy:

```gdscript
func _fire_condition_event(event_type: Trigger.TriggerType, context: Dictionary = {}) -> void:
	var snapshot := active_conditions.duplicate()
	for condition: Condition in snapshot:
		if condition == null or not active_conditions.has(condition): continue
		await _execute_condition_triggers(condition, event_type, context)
		if condition.remove_on_triggers.has(event_type) and active_conditions.has(condition):
			await _remove_condition_instance(condition)

func _execute_condition_triggers(condition: Condition, event_type: Trigger.TriggerType,
	context: Dictionary) -> void:
	for trigger: Trigger in condition.triggers:
		if trigger == null or trigger.trigger_type != event_type: continue
		if trigger.is_attack: await battle_manager.wait(0.25)
		print("Condition '", condition.condition_name, "' is firing effects for '", event_type, "'")
		var targets: Array = []
		if context.has("targets"): targets.assign(context.targets)
		var contextual_attacker: ActorCard = context.get("attacker") as ActorCard
		var action: Action = context.get("action") as Action
		for effect: ActionEffect in trigger.effects_to_run:
			if effect == null: continue
			if effect.target_type == Action.TargetType.SELF:
				targets = [self]
			else:
				targets = battle_manager.get_targets(
					effect.target_type, self is HeroCard, targets, contextual_attacker,
				)
			if battle_manager.current_actor is HeroCard and condition.is_passive \
			and event_type == Trigger.TriggerType.ON_TURN_START:
				passive_fired.emit()
			await battle_manager.execute_triggered_effect(
				condition.attacker, effect, targets, action, context,
			)
			if condition.update_turn_order: battle_manager.update_turn_order()

func _remove_condition_instance(condition: Condition) -> bool:
	if condition == null or not active_conditions.has(condition): return false
	active_conditions.erase(condition)
	await _execute_condition_triggers(condition, Trigger.TriggerType.ON_REMOVED, {})
	_update_conditions_ui(); actor_conditions_changed.emit()
	return true

func remove_condition(condition_name: String, report_missing: bool = true) -> bool:
	for condition: Condition in active_conditions.duplicate():
		if condition.condition_name == condition_name:
			return await _remove_condition_instance(condition)
	if report_missing: push_error("[ERROR] Trying to remove an invalid condition: %s -> %s" % [actor_name, condition_name])
	return false

func remove_debuffs(quantity: int) -> int:
	if quantity <= 0: return 0
	var removed_count := 0
	var snapshot := active_conditions.duplicate()
	snapshot.reverse()
	for condition: Condition in snapshot:
		if condition == null or condition.condition_type != Condition.ConditionType.DEBUFF:
			continue
		var removed := await _remove_condition_instance(condition)
		if removed: removed_count += 1
		if removed_count >= quantity: break
	return removed_count
```

- [ ] **Step 4: Await every removal call site**

Update `Effect_RemoveCondition.execute`, `Effect_RemoveDebuffs.execute`, the consumable damage-type condition path in `Effect_Damage`, and affected tests to await removal. Preserve missing-condition diagnostics only for direct invalid calls; condition effects continue to skip absent named conditions before removal.

- [ ] **Step 5: Run condition, damage, and CT tests and commit**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "battle_condition_targets|ctb_simulator|damage_effect_execution|damage_preview" -gexit
git diff --check
```

Expected: all selected suites pass.

```sh
git add src/battle/actor_card.gd src/scripts/action_effects/effect_remove_condition.gd src/scripts/action_effects/effect_remove_debuffs.gd src/scripts/action_effects/effect_damage.gd test/unit/test_battle_condition_targets.gd test/unit/test_ctb_simulator.gd
git commit -m "fix: remove only the intended combat condition"
```

---

### Task 4: After-Shift-Action Reactions

**Files:**
- Modify: `src/scripts/conditions/trigger.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `test/integration/test_battle_controller_navigation.gd`
- Modify: `test/unit/test_battle_condition_targets.gd`

**Interfaces:**
- Produces: `Trigger.TriggerType.AFTER_SHIFT_ACTION` appended after existing enum values.
- Produces: `BattleManager._finish_shift_reactions(hero: HeroCard) -> void`.
- Preserves: `ON_SHIFT` fires immediately after role identity changes.

- [ ] **Step 1: Write failing timing tests for no-action, automatic, and targeted Shifts**

Extend the existing shift fixtures and record ordered events:

```gdscript
func test_after_shift_reaction_fires_after_automatic_shift_action() -> void:
	var fixture := _shift_reaction_fixture(true, false)
	await fixture.manager._on_shift_button_pressed("right")
	assert_eq(fixture.events, ["role_changed", "shift_action", "after_shift_action"])
	fixture.free_all()

func test_after_shift_reaction_waits_for_targeted_shift_action_target() -> void:
	var fixture := _shift_reaction_fixture(false, true)
	await fixture.manager._on_shift_button_pressed("right")
	assert_eq(fixture.events, ["role_changed"])
	await fixture.manager._on_hero_clicked(fixture.target)
	assert_eq(fixture.events, ["role_changed", "shift_action", "after_shift_action"])
	fixture.free_all()

func test_shift_without_shift_action_still_finishes_reactions() -> void:
	var fixture := _shift_reaction_fixture(false, false)
	await fixture.manager._on_shift_button_pressed("right")
	assert_eq(fixture.events, ["role_changed", "after_shift_action"])
	fixture.free_all()
```

Also assert `AFTER_SHIFT_ACTION` is numerically after every existing trigger value so serialized resources keep their meanings.

- [ ] **Step 2: Run and verify missing trigger/timing failures**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "battle_controller_navigation|battle_condition_targets" -gexit
```

Expected: nonzero exit because `AFTER_SHIFT_ACTION` and `_finish_shift_reactions` do not exist.

- [ ] **Step 3: Append the trigger and finish reactions at all three paths**

Append, never insert:

```gdscript
enum TriggerType {
	ON_APPLIED,
	ON_TURN_START,
	ON_TURN_END,
	ON_SPENDING_FOCUS,
	BEFORE_BEING_ATTACKED,
	ON_BEING_HIT,
	ON_TAKING_KINETIC_DAMAGE,
	ON_TAKING_ENERGY_DAMAGE,
	AFTER_BEING_ATTACKED,
	AFTER_ATTACKING,
	ON_GAINING_GUARD,
	ON_HEALED,
	ON_SHIFT,
	ON_BREACHED,
	ON_REMOVED,
	BEFORE_BUFF_RECEIVED,
	BEFORE_DEBUFF_RECEIVED,
	ON_TRIGGERED,
	ON_HIT,
	AFTER_SHIFT_ACTION,
}
```

Add:

```gdscript
var _pending_after_shift_action: HeroCard

func _finish_shift_reactions(hero: HeroCard) -> void:
	if _pending_after_shift_action != hero: return
	_pending_after_shift_action = null
	await hero._fire_condition_event(Trigger.TriggerType.AFTER_SHIFT_ACTION)
	_update_all_enemy_intents()
	update_turn_order()
```

After `shift_role(direction)` succeeds, set `_pending_after_shift_action = current_hero`. Call `_finish_shift_reactions(current_hero)` after an automatic Shift action finishes and immediately when the new role has no Shift action. Clear `executing_action` after the automatic path's reactions so the completed Shift action cannot block the hero's next click.

At the start of `_finish_hero_turn()`, replace the unsafe direct dereference with:

```gdscript
var finished_action := executing_action
var is_shift_action := finished_action != null and finished_action.is_shift_action
```

After clearing `executing_action` and returning to `PLAYER_ACTION`, call `_finish_shift_reactions(current_actor as HeroCard)` when `is_shift_action` is true. The pending-card identity is the exact-once guard for the required targeted path.

- [ ] **Step 4: Run all shift and condition coverage and commit**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "battle_controller_navigation|battle_condition_targets|action_ct_recovery|ctb_simulator" -gexit
git diff --check
```

Expected: all selected suites pass.

```sh
git add src/scripts/conditions/trigger.gd src/battle/battle_manager.gd test/integration/test_battle_controller_navigation.gd test/unit/test_battle_condition_targets.gd
git commit -m "feat: react after shift actions resolve"
```

---

### Task 5: Combat Primitive Verification

**Files:**
- Modify: `docs/testing/ctb-combat-checklist.md`

- [ ] **Step 1: Add manual checks for contextual scaling and condition timing**

Add unchecked items for exact target-resource intent damage, enemy healing without revival, cleansing one debuff without disturbing another, and after-Shift damage occurring after the new role's Shift action.

- [ ] **Step 2: Run import, focused tests, and full suite**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect "damage_scaling_rules|damage_preview|damage_effect_execution|battle_condition_targets|battle_revival|battle_controller_navigation|ctb_simulator" -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: every command exits zero. Record full-suite test and assertion totals.

- [ ] **Step 3: Commit verification documentation**

```sh
git add docs/testing/ctb-combat-checklist.md
git commit -m "docs: add enemy combat primitive checks"
```

Do not mark manual items complete without performing them.
