extends GutTest


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
	var action := Action.new()
	action.ct_cost_percent = 75

	assert_eq(combatant.get_speed(), 30)
	assert_eq(combatant.get_action_ct_percent(action), 60)


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
