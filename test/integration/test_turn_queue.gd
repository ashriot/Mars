extends GutTest


const TURN_QUEUE_SCENE := preload("res://src/battle/turn_queue.tscn")

var queue: TurnQueue
var manager: BattleManager
var actors: Array[ActorCard] = []


func before_each() -> void:
	manager = BattleManager.new()
	queue = TURN_QUEUE_SCENE.instantiate() as TurnQueue
	queue.battle_manager = manager
	add_child_autofree(queue)
	queue.size = Vector2(120, 764)
	await get_tree().process_frame


func after_each() -> void:
	for actor in actors:
		if is_instance_valid(actor):
			actor.free()
	actors.clear()
	if is_instance_valid(manager):
		manager.free()


func _enemy(actor_name: String) -> EnemyCard:
	var actor := EnemyCard.new()
	actor.actor_name = actor_name
	actors.append(actor)
	return actor


func _hero(actor_name: String, icon: Texture2D = null) -> HeroCard:
	var actor := HeroCard.new()
	actor.actor_name = actor_name
	var definition := RoleDefinition.new()
	definition.icon = icon
	var role := RoleData.new()
	role.source_definition = definition
	actor.loaded_roles = [role]
	actor.current_role_index = 0
	actors.append(actor)
	return actor


func _projection(active: ActorCard, count: int, alternate: ActorCard = null) -> Array:
	var result: Array = [{"actor": active, "ticks_needed": 0}]
	for index in range(1, count):
		var actor := alternate if alternate and index % 2 == 1 else active
		result.append({"actor": actor, "ticks_needed": index * 5})
	return result


func test_display_projection_publishes_active_plus_twenty_future_entries() -> void:
	var hero := _hero("Asher")
	var enemy := _enemy("Scout Drone A")
	for index in 2:
		var actor := [hero, enemy][index] as ActorCard
		var stats := ActorStats.new()
		stats.speed = 100 + index * 20
		actor.current_stats = stats
		actor.battle_priority = index
	manager.actor_list = [hero, enemy]
	manager.current_actor = hero

	var projection := manager._display_projection()

	assert_eq(projection.size(), 21)
	assert_same(projection[0].actor, hero)
	assert_eq(projection[0].ticks_needed, 0)


func test_real_queue_separates_active_and_renders_faction_content() -> void:
	var icon := GradientTexture2D.new()
	var hero := _hero("Asher", icon)
	var enemy := _enemy("Scout Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": hero, "ticks_needed": 10},
		{"actor": enemy, "ticks_needed": 31},
		{"actor": hero, "ticks_needed": 50},
	], false)
	await get_tree().process_frame

	assert_same(queue.active_item.get_parent(), queue.active_slot)
	assert_eq(queue.active_item.size, ActorQueue.ACTIVE_SIZE)
	assert_true(queue.active_item.gauge._is_current)
	assert_same(queue.future_items[0].get_parent(), queue.future_content)
	assert_eq(queue.future_items[0].size, ActorQueue.FUTURE_SIZE)
	assert_eq(queue.future_items[0].gauge._faction, CTBGauge.Faction.HERO)
	assert_same(queue.future_items[0].role_icon.texture, icon)
	assert_eq(queue.future_items[1].gauge._faction, CTBGauge.Faction.ENEMY)
	assert_eq(queue.future_items[1].enemy_label.text, "SD A")
	assert_eq(queue.future_items[2].occurrence_index, 2)
	assert_eq(queue.future_items[0].occurrence_index, 1)


func test_rail_allocation_fully_exposes_eight_future_cards() -> void:
	assert_gte(queue.future_scroll.size.y, float(8 * 72 + 7 * 8))
	assert_eq(
		queue.future_scroll.horizontal_scroll_mode,
		ScrollContainer.SCROLL_MODE_DISABLED,
	)


func test_preview_preserves_clamps_scroll_and_new_active_resets_it() -> void:
	var hero_a := _hero("Asher")
	var hero_b := _hero("Bell")
	queue._on_turn_order_updated(_projection(hero_a, 21, hero_b), false)
	await get_tree().process_frame
	queue.future_scroll.scroll_vertical = 160
	queue._on_turn_order_updated(_projection(hero_a, 21, hero_b), false)
	await get_tree().process_frame
	assert_eq(queue.future_scroll.scroll_vertical, 160)
	queue.future_scroll.scroll_vertical = queue._max_future_scroll()
	queue._on_turn_order_updated(_projection(hero_a, 3, hero_b), false)
	await get_tree().process_frame
	assert_eq(queue.future_scroll.scroll_vertical, queue._max_future_scroll())
	queue._on_turn_order_updated(_projection(hero_b, 21, hero_a), false)
	await get_tree().process_frame
	assert_eq(queue.future_scroll.scroll_vertical, 0)


func test_rapid_refresh_after_active_change_cannot_restore_stale_scroll() -> void:
	var hero_a := _hero("Asher")
	var hero_b := _hero("Bell")
	queue._on_turn_order_updated(_projection(hero_a, 21, hero_b), false)
	await get_tree().process_frame
	queue.future_scroll.scroll_vertical = 160

	queue._on_turn_order_updated(_projection(hero_b, 21, hero_a), false)
	queue._on_turn_order_updated(_projection(hero_b, 21, hero_a), false)
	await get_tree().process_frame

	assert_eq(queue.future_scroll.scroll_vertical, 0)


func test_right_stick_scroll_does_not_change_combat_selection() -> void:
	var hero := _hero("Asher")
	var enemy := _enemy("Scout Drone")
	queue._on_turn_order_updated(_projection(hero, 21, enemy), false)
	await get_tree().process_frame
	var selected_action := Action.new()
	manager.current_action = selected_action
	enemy.is_valid_target = true

	queue.scroll_future_by_axis(1.0, 0.1)

	assert_gt(queue.future_scroll.scroll_vertical, 0)
	assert_same(manager.current_action, selected_action)
	assert_true(enemy.is_valid_target)


func test_right_stick_scroll_accumulates_fractional_pixels_across_small_frames() -> void:
	var hero := _hero("Asher")
	queue._on_turn_order_updated(_projection(hero, 21), false)
	await get_tree().process_frame

	for frame in 10:
		queue.scroll_future_by_axis(1.0, 0.001)
	var small_frame_scroll := queue.future_scroll.scroll_vertical
	queue.future_scroll.scroll_vertical = 0
	queue.scroll_future_by_axis(1.0, 0.01)

	assert_eq(small_frame_scroll, 7)
	assert_eq(queue.future_scroll.scroll_vertical, small_frame_scroll)


func test_right_stick_fraction_resets_across_dead_zone_and_direction_change() -> void:
	var hero := _hero("Asher")
	queue._on_turn_order_updated(_projection(hero, 21), false)
	await get_tree().process_frame

	queue.scroll_future_by_axis(1.0, 0.0005)
	queue.scroll_future_by_axis(0.0, 0.1)
	queue.scroll_future_by_axis(1.0, 0.001)
	assert_eq(queue.future_scroll.scroll_vertical, 0)

	queue.scroll_future_by_axis(0.0, 0.1)
	queue.future_scroll.scroll_vertical = 10
	queue.scroll_future_by_axis(1.0, 0.0005)
	queue.scroll_future_by_axis(-1.0, 0.001)
	assert_eq(queue.future_scroll.scroll_vertical, 10)


func test_overflow_fade_tracks_scroll_extent() -> void:
	var hero := _hero("Asher")
	queue._on_turn_order_updated(_projection(hero, 21), false)
	await get_tree().process_frame
	queue._update_overflow_fade()
	assert_true(queue.overflow_fade.visible)
	queue.future_scroll.scroll_vertical = queue._max_future_scroll()
	queue._update_overflow_fade()
	assert_false(queue.overflow_fade.visible)
	queue._on_turn_order_updated(_projection(hero, 3), false)
	await get_tree().process_frame
	queue._update_overflow_fade()
	assert_false(queue.overflow_fade.visible)


func test_clear_hides_overflow_fade_before_layout_recalculates() -> void:
	var hero := _hero("Asher")
	queue._on_turn_order_updated(_projection(hero, 21), false)
	await get_tree().process_frame
	queue._update_overflow_fade()
	assert_true(queue.overflow_fade.visible)

	queue._on_turn_order_updated([], false)

	assert_false(queue.overflow_fade.visible)


func test_rapid_projections_cancel_stale_layout_tweens() -> void:
	var hero := _hero("Asher")
	var enemy := _enemy("Scout Drone")
	queue._on_turn_order_updated(_projection(hero, 8, enemy), true)
	queue._on_turn_order_updated(_projection(hero, 8), true)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION + 0.05).timeout

	for index in queue.future_items.size():
		var item := queue.future_items[index] as ActorQueue
		assert_eq(item.position.y, index * (ActorQueue.FUTURE_SIZE.y + TurnQueue.ITEM_SPACING))
