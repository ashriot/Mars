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


class AdvancementHero extends HeroCard:
	func highlight(_value: bool) -> void:
		return

	func on_turn_started() -> void:
		return


class AdvancementBattleManager extends BattleManager:
	var intent_refresh_count := 0

	func _flush_all_health_animations() -> void:
		return

	func _update_all_enemy_intents() -> void:
		intent_refresh_count += 1


class PublishingBattleManager extends BattleManager:
	func _flush_all_health_animations() -> void:
		return

	func wait(_duration: float = 0.01) -> void:
		return


class PublishingActor extends ActorCard:
	func show_action(_action_name: String) -> void:
		return

	func hide_action() -> void:
		return


class BreachSignalActor extends ActorCard:
	func _start_breach_pulse() -> void:
		return

	func shake_panel(_intensity: float = 0.5) -> void:
		return

	func _fire_condition_event(
		_event_type: Trigger.TriggerType,
		_context: Dictionary = {},
	) -> void:
		return


class BreachLifecycleActor extends ActorCard:
	func _start_breach_pulse() -> void:
		return

	func shake_panel(_intensity: float = 0.5) -> void:
		return


class SuspendingBreachEffect extends ActionEffect:
	signal released

	var event_log: Array[String]

	func _init(log: Array[String]) -> void:
		event_log = log
		target_type = Action.TargetType.SELF

	func execute(
		_attacker: ActorCard,
		_parent_targets: Array,
		_battle_manager: BattleManager,
		_action: Action = null,
		_context: Dictionary = {},
	) -> void:
		event_log.append("enemy_observer_started")
		await released
		event_log.append("enemy_observer_finished")


class BreachLogEffect extends ActionEffect:
	var event_log: Array[String]

	func _init(log: Array[String]) -> void:
		event_log = log
		target_type = Action.TargetType.SELF

	func execute(
		_attacker: ActorCard,
		_parent_targets: Array,
		_battle_manager: BattleManager,
		_action: Action = null,
		_context: Dictionary = {},
	) -> void:
		event_log.append("breached_actor_on_breached")


class BreachObserverHero extends HeroCard:
	var recorded_events: Array[Trigger.TriggerType] = []
	var recorded_contexts: Array[Dictionary] = []

	func _fire_condition_event(
		event_type: Trigger.TriggerType,
		context: Dictionary = {},
	) -> void:
		recorded_events.append(event_type)
		recorded_contexts.append(context.duplicate())


class BreachObserverEnemy extends EnemyCard:
	var recorded_events: Array[Trigger.TriggerType] = []

	func _fire_condition_event(
		event_type: Trigger.TriggerType,
		_context: Dictionary = {},
	) -> void:
		recorded_events.append(event_type)


class BreachBattleManager extends BattleManager:
	var update_count := 0

	func update_turn_order() -> void:
		update_count += 1


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
	var queue := CTBSimulator.project([actor], 4000, 1)
	assert_eq(queue[0].ticks_needed, 50)
	actor.free()


func test_breach_signal_supplies_actor() -> void:
	var actor := BreachSignalActor.new()
	actor.actor_name = "Signal target"
	actor.breached_label = Label.new()
	actor.guard_bar = HBoxContainer.new()
	var received: Array[ActorCard] = []
	actor.actor_breached.connect(
		func(value: ActorCard) -> void: received.append(value)
	)

	await actor.breach()

	assert_eq(received, [actor])
	actor.breached_label.free()
	actor.guard_bar.free()
	actor.free()


func test_enemy_breach_notifies_only_living_opposing_observers() -> void:
	var manager := BreachBattleManager.new()
	var breached_enemy := BreachObserverEnemy.new()
	var enemy_ally := BreachObserverEnemy.new()
	var living_hero := BreachObserverHero.new()
	var defeated_hero := BreachObserverHero.new()
	breached_enemy.is_defeated = false
	enemy_ally.is_defeated = false
	living_hero.is_defeated = false
	defeated_hero.is_defeated = true
	manager.actor_list = [breached_enemy, enemy_ally, living_hero, defeated_hero]

	await manager._on_actor_breached(breached_enemy)

	assert_eq(manager.update_count, 1)
	assert_eq(
		living_hero.recorded_events,
		[Trigger.TriggerType.ON_ENEMY_BREACHED],
	)
	assert_eq(living_hero.recorded_contexts.size(), 1)
	assert_same(living_hero.recorded_contexts[0].target, breached_enemy)
	assert_eq(living_hero.recorded_contexts[0].targets, [breached_enemy])
	assert_eq(defeated_hero.recorded_events, [])
	assert_eq(enemy_ally.recorded_events, [])
	assert_eq(breached_enemy.recorded_events, [])
	manager.free()
	breached_enemy.free()
	enemy_ally.free()
	living_hero.free()
	defeated_hero.free()


func test_breach_awaits_enemy_observer_before_own_breached_event() -> void:
	var manager := BreachBattleManager.new()
	var breached_actor := BreachLifecycleActor.new()
	var observer := HeroCard.new()
	breached_actor.actor_name = "Awaited breach target"
	breached_actor.breached_label = Label.new()
	breached_actor.guard_bar = HBoxContainer.new()
	breached_actor.battle_manager = manager
	observer.battle_manager = manager
	breached_actor.is_defeated = false
	observer.is_defeated = false
	manager.actor_list = [breached_actor, observer]
	var event_log: Array[String] = []
	var suspending_effect := SuspendingBreachEffect.new(event_log)
	var observer_trigger := Trigger.new()
	observer_trigger.trigger_type = Trigger.TriggerType.ON_ENEMY_BREACHED
	observer_trigger.effects_to_run = [suspending_effect]
	var observer_condition := Condition.new()
	observer_condition.condition_name = "Teamwork observer"
	observer_condition.attacker = observer
	observer_condition.triggers = [observer_trigger]
	observer.active_conditions = [observer_condition]
	var breached_trigger := Trigger.new()
	breached_trigger.trigger_type = Trigger.TriggerType.ON_BREACHED
	breached_trigger.effects_to_run = [BreachLogEffect.new(event_log)]
	var breached_condition := Condition.new()
	breached_condition.condition_name = "Breach reaction"
	breached_condition.attacker = breached_actor
	breached_condition.triggers = [breached_trigger]
	breached_actor.active_conditions = [breached_condition]

	breached_actor.breach()

	assert_eq(event_log, ["enemy_observer_started"])
	assert_eq(manager.update_count, 1)
	suspending_effect.released.emit()
	await get_tree().process_frame
	assert_eq(event_log, [
		"enemy_observer_started",
		"enemy_observer_finished",
		"breached_actor_on_breached",
	])
	breached_actor.breached_label.free()
	breached_actor.guard_bar.free()
	breached_actor.free()
	observer.free()
	manager.free()


func test_zero_or_negative_speed_uses_one_consistently() -> void:
	var actor := _actor(true, 0, 0, 0)
	var queue := CTBSimulator.project([actor], 4000, 1)
	assert_eq(queue[0].ticks_needed, 4000)
	actor.free()


func test_exact_ties_use_speed_then_faction_then_priority() -> void:
	var fast_enemy := _actor(false, 200, 0, 3)
	var slow_hero := _actor(true, 100, 2000, 2)
	var first_hero := _actor(true, 100, 2000, 0)
	var second_hero := _actor(true, 100, 2000, 1)
	var queue := CTBSimulator.project(
		[second_hero, slow_hero, fast_enemy, first_hero], 4000, 4
	)
	assert_same(queue[0].actor, fast_enemy, "higher Speed wins an equal arrival tick")
	assert_same(queue[1].actor, first_hero, "heroes then use immutable lower priority")
	for actor in [fast_enemy, slow_hero, first_hero, second_hero]:
		actor.free()


func test_equal_tick_equal_speed_hero_wins_over_enemy() -> void:
	var enemy := _actor(false, 100, 0, 0)
	var hero := _actor(true, 100, 0, 1)

	var queue := CTBSimulator.project([enemy, hero], 4000, 1)

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

	var queue := CTBSimulator.project(actors, 4000, 1)

	assert_same(queue[0].actor, first, "revival order does not replace spawn priority")
	first.free()
	second.free()


func test_repeated_projection_is_identical() -> void:
	var first := _actor(false, 100, 0, 0)
	var second := _actor(false, 100, 0, 1)
	var first_projection := CTBSimulator.project([first, second], 4000, 10)
	var second_projection := CTBSimulator.project([first, second], 4000, 10)
	assert_eq(
		first_projection.map(func(entry): return entry.actor),
		second_projection.map(func(entry): return entry.actor)
	)
	first.free()
	second.free()


func test_adjustments_do_not_mutate_live_ct() -> void:
	var actor := _actor(true, 100, 0, 0)
	var queue := CTBSimulator.project([actor], 4000, 1, {actor: -400})
	assert_eq(queue[0].ticks_needed, 44)
	assert_eq(actor.current_ct, 0)
	actor.free()


func test_projection_uses_normalized_ct_speed() -> void:
	var actor := _actor(true, 200, 0, 0)
	actor.ct_speed_scale = 0.5

	var queue := CTBSimulator.project([actor], 4000, 1)

	assert_eq(actor.get_ct_speed(), 100)
	assert_eq(queue[0].ticks_needed, 40)
	actor.free()


func test_equal_normalized_arrival_uses_raw_speed_as_secondary_tie() -> void:
	var slower := _actor(true, 100, 0, 0)
	var faster := _actor(false, 101, 0, 1)
	slower.ct_speed_scale = 0.01
	faster.ct_speed_scale = 0.01

	var queue := CTBSimulator.project([slower, faster], 10, 1)

	assert_eq(slower.get_ct_speed(), faster.get_ct_speed())
	assert_same(queue[0].actor, faster)
	slower.free()
	faster.free()


func test_battle_scale_freezes_across_speed_conditions_and_actor_revival() -> void:
	var manager := BattleManager.new()
	var slow_actor := _actor(true, 100, 0, 0)
	var fast_actor := _actor(false, 200, 0, 1)
	manager.actor_list = [slow_actor, fast_actor]
	manager._configure_battle_ct_speed_scale()
	var frozen_scale: float = manager.battle_ct_speed_scale
	var initial_fast_ct_speed := fast_actor.get_ct_speed()
	var speed_condition := Condition.new()
	speed_condition.speed_scalar = 0.5

	fast_actor.active_conditions = [speed_condition]
	manager.actor_list.erase(fast_actor)
	manager._on_actor_revived(fast_actor)

	assert_ne(fast_actor.get_ct_speed(), initial_fast_ct_speed)
	assert_eq(manager.battle_ct_speed_scale, frozen_scale)
	assert_eq(slow_actor.ct_speed_scale, frozen_scale)
	assert_eq(fast_actor.ct_speed_scale, frozen_scale)
	slow_actor.free()
	fast_actor.free()
	manager.free()


func test_head_starts_add_normalized_ct_without_replacing_passive_adjustment() -> void:
	var manager := BattleManager.new()
	var slow_actor := _actor(true, 100, 400, 0)
	var fast_actor := _actor(false, 200, 0, 1)
	manager.actor_list = [slow_actor, fast_actor]
	manager._configure_battle_ct_speed_scale()
	var frozen_scale: float = manager.battle_ct_speed_scale

	manager._apply_initial_ct_head_starts([0.0, 1.0])

	assert_eq(slow_actor.current_ct, 400)
	assert_eq(fast_actor.current_ct, fast_actor.get_ct_speed() * 5)
	assert_eq(slow_actor.ct_speed_scale, frozen_scale)
	assert_eq(fast_actor.ct_speed_scale, frozen_scale)
	slow_actor.free()
	fast_actor.free()
	manager.free()


func test_live_advancement_matches_projected_normalized_ticks() -> void:
	var manager := AdvancementBattleManager.new()
	manager.action_bar = ActionBar.new()
	var winner := AdvancementHero.new()
	winner.current_stats = ActorStats.new()
	winner.current_stats.speed = 200
	winner.ct_speed_scale = 0.5
	var observer := ActorCard.new()
	observer.current_stats = ActorStats.new()
	observer.current_stats.speed = 50
	observer.ct_speed_scale = 2.0
	manager.actor_list = [winner, observer]
	var kinds: Array[int] = []
	manager.turn_order_updated.connect(
		func(_queue: Array, kind: BattleManager.TurnOrderUpdate) -> void:
			kinds.append(kind)
	)

	manager.find_and_start_next_turn()

	assert_same(manager.current_actor, winner)
	assert_eq(observer.current_ct, manager.TARGET_CT)
	assert_eq(kinds, [BattleManager.TurnOrderUpdate.ADVANCE])
	assert_eq(manager.intent_refresh_count, 1)
	winner.free()
	observer.free()
	manager.action_bar.free()
	manager.free()


func test_active_actor_stays_first_and_remains_in_future_projection() -> void:
	var manager := BattleManager.new()
	var active_actor := _actor(true, 100, 0, 0)
	var other_actor := _actor(false, 200, 0, 1)
	manager.actor_list = [active_actor, other_actor]
	manager.current_actor = active_actor
	var emitted_queue: Array = []
	manager.turn_order_updated.connect(
		func(queue: Array, _kind: BattleManager.TurnOrderUpdate) -> void:
			emitted_queue.assign(queue)
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


func test_manager_publishes_explicit_preview_and_refresh_kinds() -> void:
	var manager := BattleManager.new()
	var actor := _actor(true, 100, 0, 0)
	manager.actor_list = [actor]
	manager.current_actor = actor
	var kinds: Array[int] = []
	manager.turn_order_updated.connect(
		func(_queue: Array, kind: BattleManager.TurnOrderUpdate) -> void:
			kinds.append(kind)
	)

	manager.update_turn_order()
	manager.preview_action_turn_order(actor, Action.new())

	assert_eq(kinds, [
		BattleManager.TurnOrderUpdate.REFRESH,
		BattleManager.TurnOrderUpdate.PREVIEW,
	])
	actor.free()
	manager.free()


func test_visible_execution_commits_but_hidden_passive_execution_does_not() -> void:
	var manager := PublishingBattleManager.new()
	var actor := PublishingActor.new()
	actor.current_stats = ActorStats.new()
	actor.current_stats.speed = 100
	actor.actor_name = "Publisher"
	manager.actor_list = [actor]
	manager.current_actor = actor
	var kinds: Array[int] = []
	manager.turn_order_updated.connect(
		func(_queue: Array, kind: BattleManager.TurnOrderUpdate) -> void:
			kinds.append(kind)
	)

	await manager.execute_action(actor, Action.new(), [], true, false)
	await manager.execute_action(actor, Action.new(), [], false, false)

	assert_eq(kinds, [BattleManager.TurnOrderUpdate.COMMIT])
	actor.free()
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

	await actor.remove_condition("Buff")
	assert_signal_emit_count(manager, "turn_order_updated", 2)
	assert_eq(manager.intent_refresh_count, 2)

	await actor.remove_condition("Missing")
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
	await actor.remove_debuffs(2)
	assert_signal_emit_count(manager, "turn_order_updated", 3, "batch removal publishes once")
	assert_eq(manager.intent_refresh_count, 3)

	await actor.remove_debuffs(2)
	assert_signal_emit_count(manager, "turn_order_updated", 3, "empty batch removal is silent")
	assert_eq(manager.intent_refresh_count, 3)
	actor.free()
	manager.free()
