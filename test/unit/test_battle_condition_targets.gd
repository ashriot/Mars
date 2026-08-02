extends GutTest

const CardTestFactory := preload("res://test/helpers/card_test_factory.gd")


class RecordingEffect extends ActionEffect:
	var event_label: String
	var event_log: Array[String]

	func _init(label: String, log: Array[String]) -> void:
		event_label = label
		event_log = log
		target_type = Action.TargetType.SELF

	func execute(
		_attacker: ActorCard,
		_parent_targets: Array,
		_battle_manager: BattleManager,
		_action: Action = null,
		_context: Dictionary = {},
	) -> void:
		event_log.append(event_label)


class CapturingBattleManager extends BattleManager:
	var captured_targets: Array = []

	func wait(_duration: float = 0.01) -> void:
		pass

	func execute_triggered_effect(
		_actor: Node,
		_effect: ActionEffect,
		targets: Array,
		_action: Action,
		_context: Dictionary = {},
	) -> void:
		captured_targets = targets
		await _effect.execute(_actor as ActorCard, targets, self, _action, _context)


class ConditionActor extends ActorCard:
	func _update_conditions_ui() -> void:
		return


class ConditionHeroCard extends HeroCard:
	func _update_conditions_ui() -> void:
		return

	func update_focus_bar(_animate: bool = true) -> void:
		return


func test_off_turn_condition_self_target_resolves_to_condition_owner() -> void:
	var manager := CapturingBattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	var hero := CardTestFactory.hero(null, manager)
	var enemy := CardTestFactory.enemy(null, manager)
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	manager.current_actor = enemy
	hero.battle_manager = manager
	hero.is_defeated = false
	enemy.is_defeated = false
	hero_area.add_child(hero)
	enemy_area.add_child(enemy)

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
	hero_area.free()
	enemy_area.free()


func test_focus_refund_restores_paid_cost_and_consumes_condition() -> void:
	var hero := CardTestFactory.bind(
		ConditionHeroCard.new(), BattleCombatant.Faction.HERO,
	) as ConditionHeroCard
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
	var hero := CardTestFactory.bind(
		ConditionHeroCard.new(), BattleCombatant.Faction.HERO,
	) as ConditionHeroCard
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
	var hero_area := Control.new()
	var enemy_area := Control.new()
	var echo := CardTestFactory.hero(null, manager)
	var living_hero := CardTestFactory.hero(null, manager)
	var defeated_hero := CardTestFactory.hero(null, manager)
	var enemy_holder := CardTestFactory.enemy(null, manager)
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	manager.current_actor = enemy_holder
	enemy_holder.battle_manager = manager
	for hero: HeroCard in [echo, living_hero, defeated_hero]:
		hero.is_defeated = hero == defeated_hero
		hero_area.add_child(hero)
	enemy_holder.is_defeated = false
	enemy_area.add_child(enemy_holder)

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
	hero_area.free()
	enemy_area.free()


func test_non_self_condition_uses_holder_allegiance_when_caster_is_invalid() -> void:
	var manager := CapturingBattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	var holder := CardTestFactory.hero(null, manager)
	var living_hero := CardTestFactory.hero(null, manager)
	var enemy := CardTestFactory.enemy(null, manager)
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	manager.current_actor = enemy
	holder.battle_manager = manager
	holder.is_defeated = false
	living_hero.is_defeated = false
	enemy.is_defeated = false
	hero_area.add_child(holder)
	hero_area.add_child(living_hero)
	enemy_area.add_child(enemy)

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
	hero_area.free()
	enemy_area.free()


func test_healing_effect_heals_living_enemy_without_hero_focus_scaling() -> void:
	var manager := CapturingBattleManager.new()
	var attacker := CardTestFactory.enemy(null, manager)
	attacker.current_stats = ActorStats.new()
	attacker.current_stats.psyche = 20
	var target := CardTestFactory.enemy(null, manager)
	target.current_stats = ActorStats.new()
	target.current_stats.max_hp = 100
	target.hp_bar_ghost = ProgressBar.new()
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
	target.hp_bar_ghost.free()
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

	var single_targets: Array = fixture.manager.get_targets(
		Action.TargetType.ONE_ALLY, true, [], fixture.healer, action.can_revive_targets,
	)
	var group_targets: Array = fixture.manager.get_targets(
		Action.TargetType.ALL_ALLIES, true, [], fixture.healer, action.can_revive_targets,
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

	var targets: Array = fixture.manager.get_targets(
		Action.TargetType.ONE_ALLY, true, [], fixture.healer, action.can_revive_targets,
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
	var actor := CardTestFactory.bind(
		ConditionActor.new(), BattleCombatant.Faction.HERO, null, manager,
	) as ConditionActor
	actor.battle_manager = manager
	manager.current_actor = actor
	return {"actor": actor, "manager": manager}


func _free_condition_fixture(fixture: Dictionary) -> void:
	(fixture.actor as ActorCard).free()
	(fixture.manager as BattleManager).free()


func _healing_target_fixture() -> Dictionary:
	var manager := CapturingBattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	var healer := CardTestFactory.hero(null, manager)
	var defeated := CardTestFactory.hero(null, manager)
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	manager.current_actor = healer
	healer.is_defeated = false
	defeated.is_defeated = true
	hero_area.add_child(healer)
	hero_area.add_child(defeated)
	return {
		manager = manager,
		hero_area = hero_area,
		enemy_area = enemy_area,
		healer = healer,
		defeated = defeated,
	}


func _free_healing_target_fixture(fixture: Dictionary) -> void:
	(fixture.manager as BattleManager).free()
	(fixture.hero_area as Control).free()
	(fixture.enemy_area as Control).free()


func _defeated_condition_healing_fixture() -> Dictionary:
	var manager := CapturingBattleManager.new()
	var attacker := CardTestFactory.enemy(null, manager)
	var holder := CardTestFactory.bind(
		ConditionHeroCard.new(), BattleCombatant.Faction.HERO, null, manager,
	) as ConditionHeroCard
	attacker.current_stats = ActorStats.new()
	attacker.current_stats.psyche = 20
	holder.current_stats = ActorStats.new()
	holder.current_stats.max_hp = 100
	holder.hp_bar_ghost = ProgressBar.new()
	holder.current_hp = 0
	holder.is_defeated = true
	holder.battle_manager = manager
	manager.current_actor = holder
	return {manager = manager, attacker = attacker, holder = holder}


func _free_defeated_condition_healing_fixture(fixture: Dictionary) -> void:
	(fixture.manager as BattleManager).free()
	(fixture.attacker as EnemyCard).free()
	(fixture.holder as HeroCard).hp_bar_ghost.free()
	(fixture.holder as HeroCard).free()


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
