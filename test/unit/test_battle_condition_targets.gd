extends GutTest

class RecordingEffect extends ActionEffect:
	var event_label: String
	var event_log: Array[String]

	func _init(label: String, log: Array[String]) -> void:
		event_label = label
		event_log = log
		target_type = Action.TargetType.SELF

	func execute(
		_attacker: BattleCombatant,
		_parent_targets: Array[BattleCombatant],
		_battle_manager: BattleManager,
		_action: Action = null,
		_context: Dictionary = {},
	) -> void:
		event_log.append(event_label)


class IdentityRecordingEffect extends ActionEffect:
	var received_attacker: BattleCombatant
	var received_targets: Array[BattleCombatant] = []

	func execute(
		attacker: BattleCombatant,
		parent_targets: Array[BattleCombatant],
		_battle_manager: BattleManager,
		_action: Action = null,
		_context: Dictionary = {},
	) -> void:
		received_attacker = attacker
		received_targets.assign(parent_targets)


class CapturingBattleManager extends BattleManager:
	var captured_targets: Array[BattleCombatant] = []

	func wait(_duration: float = 0.01) -> void:
		pass

	func execute_triggered_effect(
		_actor: BattleCombatant,
		_effect: ActionEffect,
		targets: Array[BattleCombatant],
		_action: Action,
		_context: Dictionary = {},
	) -> void:
		captured_targets.assign(targets)
		await _effect.execute(_actor, targets, self, _action, _context)


class IdentityTargetingBattleManager extends BattleManager:
	var returned_targets: Array[BattleCombatant] = []
	var received_parent_targets: Array[BattleCombatant] = []
	var received_attacker: BattleCombatant
	var executed_actor: BattleCombatant
	var executed_targets: Array[BattleCombatant] = []

	func wait(_duration: float = 0.01) -> void:
		return

	func get_targets(
		_target_type: Action.TargetType,
		_friendly: bool,
		parent_targets: Array[BattleCombatant] = [],
		attacker: BattleCombatant = null,
		_include_defeated_heroes: bool = false,
	) -> Array[BattleCombatant]:
		received_parent_targets.assign(parent_targets)
		received_attacker = attacker
		var result: Array[BattleCombatant] = []
		result.assign(returned_targets)
		return result

	func execute_triggered_effect(
		actor: BattleCombatant,
		effect: ActionEffect,
		targets: Array[BattleCombatant],
		action: Action,
		context: Dictionary = {},
	) -> void:
		executed_actor = actor
		executed_targets.assign(targets)
		await effect.execute(actor, targets, self, action, context)


class ConditionActor extends BattleCombatant:
	pass


class ConditionHero extends HeroCombatant:
	pass


func test_modify_focus_uses_combatant_targets_around_manager_targeting() -> void:
	var manager := IdentityTargetingBattleManager.new()
	var attacker := _hero(manager)
	var target := _hero(manager)
	manager.returned_targets = [target]
	var effect := Effect_ModifyFocus.new()
	effect.focus_amount = 2

	await effect.execute(attacker, [target], manager)

	assert_eq(manager.received_parent_targets, [target])
	assert_same(manager.received_attacker, attacker)
	assert_eq(target.current_focus, 2)
	manager.free()
	attacker.free()
	target.free()


func test_recover_breach_uses_combatant_identities_around_manager_targeting() -> void:
	var manager := IdentityTargetingBattleManager.new()
	var attacker := _hero(manager)
	var target_stats := ActorStats.new()
	target_stats.max_hp = 100
	target_stats.starting_guard = 6
	var target := _hero(manager, target_stats)
	target.current_guard = 0
	target.is_breached = true
	manager.returned_targets = [target]
	var effect := Effect_RecoverBreach.new()
	effect.effect_target_type = Action.TargetType.PARENT

	await effect.execute(attacker, [target], manager)

	assert_eq(manager.received_parent_targets, [target])
	assert_same(manager.received_attacker, attacker)
	assert_false(target.is_breached)
	assert_eq(target.current_guard, 3)
	manager.free()
	attacker.free()
	target.free()


func test_condition_retargeting_preserves_combatant_identity() -> void:
	var manager := IdentityTargetingBattleManager.new()
	var holder := _hero(manager)
	var source := _hero(manager)
	var target := _enemy(manager)
	manager.current_actor = holder
	manager.returned_targets = [target]
	var effect := IdentityRecordingEffect.new()
	effect.target_type = Action.TargetType.PARENT
	var trigger := Trigger.new()
	trigger.trigger_type = Trigger.TriggerType.ON_TRIGGERED
	trigger.effects_to_run = [effect]
	var condition := Condition.new()
	condition.condition_name = "Identity bridge"
	condition.attacker = source
	condition.triggers = [trigger]
	holder.active_conditions = [condition]

	await holder._fire_condition_event(
		Trigger.TriggerType.ON_TRIGGERED,
		{"attacker": source, "targets": [target]},
	)

	assert_eq(manager.received_parent_targets, [target])
	assert_same(manager.received_attacker, source)
	assert_same(manager.executed_actor, source)
	assert_eq(manager.executed_targets, [target])
	assert_same(effect.received_attacker, source)
	assert_eq(effect.received_targets, [target])
	manager.free()
	holder.free()
	source.free()
	target.free()


func test_off_turn_condition_self_target_resolves_to_condition_owner() -> void:
	var manager := CapturingBattleManager.new()
	var hero := _hero(manager)
	var enemy := _enemy(manager)
	manager.actor_list = [hero, enemy]
	manager.current_actor = enemy
	hero.is_defeated = false
	enemy.is_defeated = false

	var effect := ActionEffect.new()
	effect.target_type = Action.TargetType.SELF
	var trigger := Trigger.new()
	trigger.trigger_type = Trigger.TriggerType.ON_REMOVED
	trigger.effects_to_run = [effect]
	var condition := Condition.new()
	condition.condition_name = "Off-turn self heal"
	condition.attacker = enemy
	condition.triggers = [trigger]
	hero.active_conditions = [condition]

	await hero._fire_condition_event(Trigger.TriggerType.ON_REMOVED)

	assert_eq(manager.captured_targets, [hero])
	manager.free()
	hero.free()
	enemy.free()


func test_focus_refund_restores_paid_cost_and_consumes_condition() -> void:
	var hero := _setup_combatant(
		ConditionHero.new(), BattleCombatant.Faction.HERO,
	) as ConditionHero
	hero.current_focus = 5
	var refund := Condition.new()
	refund.condition_name = "Coordinate"
	refund.refund_focus_cost_on_spend = true
	refund.remove_on_triggers = [Trigger.TriggerType.ON_SPENDING_FOCUS]
	hero.active_conditions = [refund]

	await hero.modify_focus(-3, {"paid_focus_cost": 3})

	assert_eq(hero.current_focus, 5)
	assert_false(hero.active_conditions.has(refund))
	hero.free()


func test_zero_focus_modification_without_action_context_preserves_refund() -> void:
	var hero := _setup_combatant(
		ConditionHero.new(), BattleCombatant.Faction.HERO,
	) as ConditionHero
	var refund := Condition.new()
	refund.condition_name = "Coordinate"
	refund.refund_focus_cost_on_spend = true
	refund.remove_on_triggers = [Trigger.TriggerType.ON_SPENDING_FOCUS]
	hero.active_conditions = [refund]

	await hero.modify_focus(0)

	assert_true(hero.active_conditions.has(refund))
	hero.free()


func test_enemy_held_condition_targets_living_allies_of_hero_caster() -> void:
	var manager := CapturingBattleManager.new()
	var echo := _hero(manager)
	var living_hero := _hero(manager)
	var defeated_hero := _hero(manager)
	var enemy_holder := _enemy(manager)
	manager.actor_list = [echo, living_hero, defeated_hero, enemy_holder]
	manager.current_actor = enemy_holder
	for hero: HeroCombatant in [echo, living_hero, defeated_hero]:
		hero.is_defeated = hero == defeated_hero
	enemy_holder.is_defeated = false

	var effect := ActionEffect.new()
	effect.target_type = Action.TargetType.ALL_ALLIES
	var trigger := Trigger.new()
	trigger.trigger_type = Trigger.TriggerType.ON_TRIGGERED
	trigger.effects_to_run = [effect]
	var condition := Condition.new()
	condition.condition_name = "Echo-authored ally effect"
	condition.attacker = echo
	condition.triggers = [trigger]
	enemy_holder.active_conditions = [condition]

	await enemy_holder._fire_condition_event(Trigger.TriggerType.ON_TRIGGERED)

	assert_eq(manager.captured_targets, [echo, living_hero])
	manager.free()
	echo.free()
	living_hero.free()
	defeated_hero.free()
	enemy_holder.free()


func test_non_self_condition_uses_holder_allegiance_when_caster_is_invalid() -> void:
	var manager := CapturingBattleManager.new()
	var holder := _hero(manager)
	var living_hero := _hero(manager)
	var enemy := _enemy(manager)
	manager.actor_list = [holder, living_hero, enemy]
	manager.current_actor = enemy
	holder.is_defeated = false
	living_hero.is_defeated = false
	enemy.is_defeated = false

	var effect := ActionEffect.new()
	effect.target_type = Action.TargetType.ALL_ALLIES
	var trigger := Trigger.new()
	trigger.trigger_type = Trigger.TriggerType.ON_TRIGGERED
	trigger.effects_to_run = [effect]
	var condition := Condition.new()
	condition.condition_name = "Holder-aligned ally effect"
	condition.attacker = null
	condition.triggers = [trigger]
	holder.active_conditions = [condition]

	await holder._fire_condition_event(Trigger.TriggerType.ON_TRIGGERED)

	assert_eq(manager.captured_targets, [holder, living_hero])
	manager.free()
	holder.free()
	living_hero.free()
	enemy.free()


func test_healing_effect_heals_living_enemy_without_hero_focus_scaling() -> void:
	var manager := CapturingBattleManager.new()
	var attacker := _enemy(manager)
	attacker.current_stats.psyche = 20
	var target := _enemy(manager)
	target.current_stats.max_hp = 100
	target.current_hp = 25
	target.is_defeated = false
	var effect := Effect_Healing.new()
	effect.potency = 1.5
	effect.focus_scalar = 1.0
	effect.is_revive = false

	await effect.execute(attacker, [target], manager)

	assert_eq(target.current_hp, 55)
	manager.free()
	attacker.free()
	target.free()


func test_healing_defaults_to_non_reviving() -> void:
	var effect := Effect_Healing.new()
	assert_false(effect.is_revive)
	var action := Action.new()
	action.effects = [effect]
	assert_false(action.can_revive_targets)


func test_explicit_revive_remains_opt_in() -> void:
	var effect := Effect_Healing.new()
	effect.is_revive = true
	var action := Action.new()
	action.effects = [effect]
	assert_true(action.can_revive_targets)


func test_ordinary_healing_skips_defeated_heroes_for_single_and_group_targets() -> void:
	var fixture := _healing_target_fixture()
	var effect := Effect_Healing.new()
	var action := Action.new()
	action.effects = [effect]
	var no_parent_targets: Array[BattleCombatant] = []

	var single_targets: Array = fixture.manager.get_targets(
		Action.TargetType.ONE_ALLY, true, no_parent_targets,
		fixture.healer, action.can_revive_targets,
	)
	var group_targets: Array = fixture.manager.get_targets(
		Action.TargetType.ALL_ALLIES, true, no_parent_targets,
		fixture.healer, action.can_revive_targets,
	)

	assert_does_not_have(single_targets, fixture.defeated)
	assert_does_not_have(group_targets, fixture.defeated)
	_free_healing_target_fixture(fixture)


func test_explicit_revive_includes_defeated_hero_in_targets() -> void:
	var fixture := _healing_target_fixture()
	var effect := Effect_Healing.new()
	effect.is_revive = true
	var action := Action.new()
	action.effects = [effect]
	var no_parent_targets: Array[BattleCombatant] = []

	var targets: Array = fixture.manager.get_targets(
		Action.TargetType.ONE_ALLY, true, no_parent_targets,
		fixture.healer, action.can_revive_targets,
	)

	assert_has(targets, fixture.defeated)
	_free_healing_target_fixture(fixture)


func test_triggered_ordinary_healing_does_not_revive_defeated_holder() -> void:
	var fixture := _defeated_condition_healing_fixture()
	var condition := _healing_condition(Trigger.TriggerType.ON_TRIGGERED)
	condition.attacker = fixture.attacker

	await fixture.holder.add_condition(condition)
	await fixture.holder._fire_condition_event(Trigger.TriggerType.ON_TRIGGERED)

	assert_eq(fixture.holder.current_hp, 0)
	assert_true(fixture.holder.is_defeated)
	_free_defeated_condition_healing_fixture(fixture)


func test_recurring_ordinary_healing_does_not_revive_defeated_holder() -> void:
	var fixture := _defeated_condition_healing_fixture()
	var condition := _healing_condition(Trigger.TriggerType.ON_TURN_START, true)
	condition.attacker = fixture.attacker

	await fixture.holder.add_condition(condition)
	await fixture.holder._fire_condition_event(Trigger.TriggerType.ON_TURN_START)

	assert_eq(fixture.holder.current_hp, 0)
	assert_true(fixture.holder.is_defeated)
	_free_defeated_condition_healing_fixture(fixture)


func test_removing_one_condition_fires_only_its_on_removed_effect_once() -> void:
	var fixture := _condition_fixture()
	var removed_log: Array[String] = []
	var conditions: Array[Condition] = [
		_condition_with_removed_effect("First", removed_log),
		_condition_with_removed_effect("Second", removed_log),
	]
	fixture.actor.active_conditions = conditions

	var removed: Variant = await fixture.actor.remove_condition("First")

	assert_true(removed)
	assert_eq(removed_log, ["First"])
	assert_false(fixture.actor.has_condition("First"))
	assert_true(fixture.actor.has_condition("Second"))
	_free_condition_fixture(fixture)


func test_remove_on_event_runs_event_effect_then_own_removal_once() -> void:
	var fixture := _condition_fixture()
	var event_log: Array[String] = []
	var condition := _condition_with_event_and_removed_effect("Bomb", event_log)
	condition.remove_on_triggers = [Trigger.TriggerType.ON_SHIFT]
	var conditions: Array[Condition] = [condition]
	fixture.actor.active_conditions = conditions

	await fixture.actor._fire_condition_event(Trigger.TriggerType.ON_SHIFT)

	assert_eq(event_log, ["shift:Bomb", "removed:Bomb"])
	assert_false(fixture.actor.has_condition("Bomb"))
	_free_condition_fixture(fixture)


func test_remove_debuffs_returns_exact_removed_count() -> void:
	var fixture := _condition_fixture()
	var conditions: Array[Condition] = [_debuff("A"), _debuff("B"), _buff("C")]
	fixture.actor.active_conditions = conditions

	var removed_count: Variant = await fixture.actor.remove_debuffs(1)

	assert_eq(removed_count, 1)
	assert_eq(fixture.actor.count_debuffs(), 1)
	assert_true(fixture.actor.has_condition("C"))
	_free_condition_fixture(fixture)


func test_new_trigger_values_are_appended_after_existing_values() -> void:
	assert_gt(Trigger.TriggerType.AFTER_SHIFT_ACTION, Trigger.TriggerType.ON_HIT)
	assert_gt(
		Trigger.TriggerType.ON_ENEMY_BREACHED,
		Trigger.TriggerType.AFTER_SHIFT_ACTION,
	)
	assert_eq(
		Trigger.TriggerType.ON_ENEMY_BREACHED,
		Trigger.TriggerType.values().max(),
	)


func _condition_fixture() -> Dictionary:
	var manager := CapturingBattleManager.new()
	var actor := _setup_combatant(
		ConditionActor.new(), BattleCombatant.Faction.HERO, null, manager,
	) as ConditionActor
	manager.current_actor = actor
	manager.actor_list = [actor]
	return {"actor": actor, "manager": manager}


func _free_condition_fixture(fixture: Dictionary) -> void:
	(fixture.actor as BattleCombatant).free()
	(fixture.manager as BattleManager).free()


func _healing_target_fixture() -> Dictionary:
	var manager := CapturingBattleManager.new()
	var healer := _hero(manager)
	var defeated := _hero(manager)
	manager.current_actor = healer
	manager.actor_list = [healer, defeated]
	healer.is_defeated = false
	defeated.is_defeated = true
	var healer_presentation := CombatantPresentation.new()
	var defeated_presentation := CombatantPresentation.new()
	healer_presentation.bind(healer)
	defeated_presentation.bind(defeated)
	manager.add_child(healer_presentation)
	manager.add_child(defeated_presentation)
	manager.register_presentation(healer, healer_presentation)
	manager.register_presentation(defeated, defeated_presentation)
	return {
		manager = manager,
		healer = healer,
		defeated = defeated,
	}


func _free_healing_target_fixture(fixture: Dictionary) -> void:
	(fixture.manager as BattleManager).free()
	(fixture.healer as HeroCombatant).free()
	(fixture.defeated as HeroCombatant).free()


func _defeated_condition_healing_fixture() -> Dictionary:
	var manager := CapturingBattleManager.new()
	var attacker := _enemy(manager)
	var holder := _setup_combatant(
		ConditionHero.new(), BattleCombatant.Faction.HERO, null, manager,
	) as ConditionHero
	attacker.current_stats.psyche = 20
	holder.current_stats.max_hp = 100
	holder.current_hp = 0
	holder.is_defeated = true
	manager.current_actor = holder
	manager.actor_list = [attacker, holder]
	return {manager = manager, attacker = attacker, holder = holder}


func _free_defeated_condition_healing_fixture(fixture: Dictionary) -> void:
	(fixture.manager as BattleManager).free()
	(fixture.attacker as EnemyCombatant).free()
	(fixture.holder as HeroCombatant).free()


func _healing_condition(
	event_type: Trigger.TriggerType,
	is_passive: bool = false,
) -> Condition:
	var effect := Effect_Healing.new()
	effect.target_type = Action.TargetType.SELF
	var trigger := Trigger.new()
	trigger.trigger_type = event_type
	trigger.effects_to_run = [effect]
	var condition := Condition.new()
	condition.condition_name = "Recurring Heal"
	condition.is_passive = is_passive
	condition.triggers = [trigger]
	return condition


func _condition_with_removed_effect(
	condition_name: String,
	event_log: Array[String],
	event_label: String = "",
) -> Condition:
	var condition := Condition.new()
	condition.condition_name = condition_name
	var trigger := Trigger.new()
	trigger.trigger_type = Trigger.TriggerType.ON_REMOVED
	trigger.effects_to_run = [RecordingEffect.new(
		condition_name if event_label.is_empty() else event_label,
		event_log,
	)]
	condition.triggers = [trigger]
	return condition


func _condition_with_event_and_removed_effect(
	condition_name: String,
	event_log: Array[String],
) -> Condition:
	var condition := _condition_with_removed_effect(
		condition_name, event_log, "removed:%s" % condition_name,
	)
	var trigger := Trigger.new()
	trigger.trigger_type = Trigger.TriggerType.ON_SHIFT
	trigger.effects_to_run = [
		RecordingEffect.new("shift:%s" % condition_name, event_log),
	]
	condition.triggers.push_front(trigger)
	return condition


func _debuff(condition_name: String) -> Condition:
	var condition := Condition.new()
	condition.condition_name = condition_name
	condition.condition_type = Condition.ConditionType.DEBUFF
	return condition


func _buff(condition_name: String) -> Condition:
	var condition := Condition.new()
	condition.condition_name = condition_name
	condition.condition_type = Condition.ConditionType.BUFF
	return condition


func _hero(
	manager: BattleManager,
	stats: ActorStats = null,
) -> HeroCombatant:
	return _setup_combatant(
		HeroCombatant.new(), BattleCombatant.Faction.HERO, stats, manager,
	) as HeroCombatant


func _enemy(manager: BattleManager) -> EnemyCombatant:
	return _setup_combatant(
		EnemyCombatant.new(), BattleCombatant.Faction.ENEMY, null, manager,
	) as EnemyCombatant


func _setup_combatant(
	combatant: BattleCombatant,
	faction: BattleCombatant.Faction,
	stats: ActorStats = null,
	manager: BattleManager = null,
) -> BattleCombatant:
	var setup_stats := stats if stats != null else ActorStats.new()
	if setup_stats.max_hp <= 0:
		setup_stats.max_hp = 100
	combatant.setup_base(setup_stats, faction, manager)
	return combatant
