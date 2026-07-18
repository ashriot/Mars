extends GutTest


func _ability(id: StringName, cooldown: int, initial: int = 0, one_time := false) -> EnemyAbility:
	var value := EnemyAbility.new()
	value.ability_id = id
	value.action = Action.new()
	value.cooldown_turns = cooldown
	value.initial_cooldown = initial
	value.one_time_use = one_time
	return value


func test_initial_cooldown_and_three_skipped_turns() -> void:
	var basic := _ability(&"basic", 0)
	var major := _ability(&"major", 3)
	var state := EnemyAIRuntimeState.new()
	state.initialize([basic, major])
	assert_true(state.is_ready(major))
	state.complete_turn(&"major")
	assert_eq(state.remaining(&"major"), 3)
	for expected in [2, 1, 0]:
		state.complete_turn(&"basic")
		assert_eq(state.remaining(&"major"), expected)
	assert_true(state.is_ready(major))
	assert_eq(state.completed_turns, 4)


func test_recovery_turn_ticks_without_starting_an_ability() -> void:
	var major := _ability(&"major", 3, 2)
	var state := EnemyAIRuntimeState.new()
	state.initialize([major])
	state.complete_turn()
	assert_eq(state.remaining(&"major"), 1)


func test_one_time_use_and_duplicate_cards_are_independent() -> void:
	var once := _ability(&"once", 0, 0, true)
	var left := EnemyAIRuntimeState.new()
	var right := EnemyAIRuntimeState.new()
	left.initialize([once]); right.initialize([once])
	left.complete_turn(&"once")
	assert_false(left.is_ready(once))
	assert_true(right.is_ready(once))
	assert_false(once.one_time_use == false, "authored resource was not mutated")
