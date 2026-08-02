extends GutTest


class ActionCtTrait extends Trait:
	func get_action_ct_multiplier(_action: Action) -> float:
		return 0.75


func test_setup_owns_state_without_control_or_scene_nodes() -> void:
	var stats := ActorStats.new()
	stats.actor_name = "Test Unit"
	stats.max_hp = 120
	stats.starting_guard = 4
	stats.speed = 25
	var combatant := BattleCombatant.new()
	add_child_autofree(combatant)

	combatant.setup_base(stats, BattleCombatant.Faction.ENEMY)

	assert_eq(combatant.actor_name, "Test Unit")
	assert_eq(combatant.current_hp, 120)
	assert_eq(combatant.current_guard, 4)
	assert_true(combatant.is_enemy())
	assert_false((combatant as Node) is CanvasItem)


func test_speed_and_action_recovery_include_conditions_and_traits() -> void:
	var combatant := _combatant_with_stats(20, 3)
	var condition := Condition.new()
	condition.speed_scalar = 0.5
	condition.action_ct_multiplier = 0.8
	combatant.active_conditions.append(condition)
	combatant.active_traits.append(ActionCtTrait.new())
	var action := Action.new()
	action.ct_cost_percent = 75

	assert_eq(combatant.get_speed(), 30)
	assert_eq(combatant.get_action_ct_percent(action), 45)


func test_condition_add_remove_and_debuff_count_publish_semantic_changes() -> void:
	var combatant := _combatant_with_stats(20, 3)
	var changes := {"count": 0}
	combatant.conditions_changed.connect(
		func(_actor: BattleCombatant): changes.count += 1
	)
	var debuff := Condition.new()
	debuff.condition_name = "Marked"
	debuff.condition_type = Condition.ConditionType.DEBUFF

	await combatant.add_condition(debuff)
	assert_true(combatant.has_condition("Marked"))
	assert_eq(combatant.count_debuffs(), 1)
	assert_eq(changes.count, 1)
	assert_true(await combatant.remove_condition("Marked"))
	assert_eq(changes.count, 2)


func test_damage_contributions_require_only_combatants() -> void:
	var attacker := _combatant_with_stats(20, 3)
	var target := _combatant_with_stats(20, 3)
	var condition := Condition.new()
	condition.condition_name = "Amplify"
	condition.damage_dealt_scalar = 0.25
	attacker.active_conditions.append(condition)

	assert_almost_eq(attacker.get_damage_dealt_modifier(target), 0.25, 0.0001)


func test_add_trait_copies_the_resource_and_assigns_the_requested_tier() -> void:
	var combatant := _combatant_with_stats(20, 3)
	var trait_resource := Trait.new()
	trait_resource.trait_name = "Fixture Trait"

	combatant._add_trait(trait_resource, 2)

	assert_eq(combatant.active_traits.size(), 1)
	assert_ne(combatant.active_traits[0], trait_resource)
	assert_eq(combatant.active_traits[0].current_tier, 2)


func _combatant_with_stats(speed: int, guard: int) -> BattleCombatant:
	var stats := ActorStats.new()
	stats.actor_name = "Fixture"
	stats.max_hp = 100
	stats.starting_guard = guard
	stats.speed = speed
	var combatant := BattleCombatant.new()
	add_child_autofree(combatant)
	combatant.setup_base(stats, BattleCombatant.Faction.HERO)
	return combatant
