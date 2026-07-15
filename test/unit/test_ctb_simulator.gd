extends GutTest


class ConditionActor extends ActorCard:
	func _fire_condition_event(
		_event_type: Trigger.TriggerType,
		_context: Dictionary = {},
	) -> void:
		return

	func _update_conditions_ui() -> void:
		return


class ConditionBattleManager extends BattleManager:
	var intent_refresh_count := 0

	func _update_all_enemy_intents() -> void:
		intent_refresh_count += 1


func _actor(hero: bool, speed: int, ct: int, priority: int) -> ActorCard:
	var actor: ActorCard = HeroCard.new() if hero else EnemyCard.new()
	var stats := ActorStats.new()
	stats.speed = speed
	actor.current_stats = stats
	actor.current_ct = ct
	actor.battle_priority = priority
	return actor


func test_negative_ct_requires_extra_ticks() -> void:
	var actor := _actor(true, 100, -1000, 0)
	var queue := CTBSimulator.project([actor], 5000, 1)
	assert_eq(queue[0].ticks_needed, 60)
	actor.free()


func test_zero_or_negative_speed_uses_one_consistently() -> void:
	var actor := _actor(true, 0, 0, 0)
	var queue := CTBSimulator.project([actor], 5000, 1)
	assert_eq(queue[0].ticks_needed, 5000)
	actor.free()


func test_exact_ties_use_speed_then_faction_then_priority() -> void:
	var fast_enemy := _actor(false, 200, 0, 3)
	var slow_hero := _actor(true, 100, 2500, 2)
	var first_hero := _actor(true, 100, 2500, 0)
	var second_hero := _actor(true, 100, 2500, 1)
	var queue := CTBSimulator.project(
		[second_hero, slow_hero, fast_enemy, first_hero], 5000, 4
	)
	assert_same(queue[0].actor, fast_enemy, "higher Speed wins an equal arrival tick")
	assert_same(queue[1].actor, first_hero, "heroes then use immutable lower priority")
	for actor in [fast_enemy, slow_hero, first_hero, second_hero]:
		actor.free()


func test_equal_tick_equal_speed_hero_wins_over_enemy() -> void:
	var enemy := _actor(false, 100, 0, 0)
	var hero := _actor(true, 100, 0, 1)

	var queue := CTBSimulator.project([enemy, hero], 5000, 1)

	assert_same(queue[0].actor, hero)
	enemy.free()
	hero.free()


func test_readded_actor_keeps_immutable_priority_for_ties() -> void:
	var first := _actor(true, 100, 0, 0)
	var second := _actor(true, 100, 0, 1)
	var actors := [first, second]
	first.is_defeated = true
	actors.erase(first)
	first.is_defeated = false
	actors.append(first)

	var queue := CTBSimulator.project(actors, 5000, 1)

	assert_same(queue[0].actor, first, "revival order does not replace spawn priority")
	first.free()
	second.free()


func test_repeated_projection_is_identical() -> void:
	var first := _actor(false, 100, 0, 0)
	var second := _actor(false, 100, 0, 1)
	var first_projection := CTBSimulator.project([first, second], 5000, 10)
	var second_projection := CTBSimulator.project([first, second], 5000, 10)
	assert_eq(
		first_projection.map(func(entry): return entry.actor),
		second_projection.map(func(entry): return entry.actor)
	)
	first.free()
	second.free()


func test_adjustments_do_not_mutate_live_ct() -> void:
	var actor := _actor(true, 100, 0, 0)
	var queue := CTBSimulator.project([actor], 5000, 1, {actor: -500})
	assert_eq(queue[0].ticks_needed, 55)
	assert_eq(actor.current_ct, 0)
	actor.free()


func test_active_actor_stays_first_and_remains_in_future_projection() -> void:
	var manager := BattleManager.new()
	var active_actor := _actor(true, 100, 0, 0)
	var other_actor := _actor(false, 200, 0, 1)
	manager.actor_list = [active_actor, other_actor]
	manager.current_actor = active_actor
	var emitted_queue: Array = []
	manager.turn_order_updated.connect(
		func(queue: Array, _animate: bool) -> void: emitted_queue.assign(queue)
	)

	manager.update_turn_order()

	assert_same(emitted_queue[0].actor, active_actor)
	assert_has(
		emitted_queue.slice(1).map(func(entry): return entry.actor),
		active_actor,
		"the active actor should still have a later projected turn"
	)
	active_actor.free()
	other_actor.free()
	manager.free()


func test_condition_mutations_publish_one_current_queue_through_manager() -> void:
	var manager := ConditionBattleManager.new()
	var actor := ConditionActor.new()
	actor.current_stats = ActorStats.new()
	actor.current_stats.speed = 100
	actor.battle_manager = manager
	manager.actor_list = [actor]
	manager.current_actor = actor
	actor.actor_conditions_changed.connect(manager._on_actor_conditions_changed)
	watch_signals(manager)

	var buff := Condition.new()
	buff.condition_name = "Buff"
	await actor.add_condition(buff)
	assert_signal_emit_count(manager, "turn_order_updated", 1)
	assert_eq(manager.intent_refresh_count, 1, "condition changes still recalculate intents")

	actor.remove_condition("Buff")
	assert_signal_emit_count(manager, "turn_order_updated", 2)
	assert_eq(manager.intent_refresh_count, 2)

	actor.remove_condition("Missing")
	assert_push_error("Trying to remove an invalid condition")
	assert_signal_emit_count(manager, "turn_order_updated", 2, "unsuccessful removal is silent")
	assert_eq(manager.intent_refresh_count, 2)

	var first_debuff := Condition.new()
	first_debuff.condition_name = "First debuff"
	first_debuff.condition_type = Condition.ConditionType.DEBUFF
	var second_debuff := Condition.new()
	second_debuff.condition_name = "Second debuff"
	second_debuff.condition_type = Condition.ConditionType.DEBUFF
	actor.active_conditions = [first_debuff, second_debuff]
	actor.remove_debuffs(2)
	assert_signal_emit_count(manager, "turn_order_updated", 3, "batch removal publishes once")
	assert_eq(manager.intent_refresh_count, 3)

	actor.remove_debuffs(2)
	assert_signal_emit_count(manager, "turn_order_updated", 3, "empty batch removal is silent")
	assert_eq(manager.intent_refresh_count, 3)
	actor.free()
	manager.free()
