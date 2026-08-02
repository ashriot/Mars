extends GutTest

const TURN_QUEUE_SCENE := preload("res://src/battle/turn_queue.tscn")
const BATTLE_SCENE := preload("res://src/battle/battle_scene.tscn")
const ARCHIVO := preload("res://data/theme/fonts/archivo.tres")
const ResponsiveFixture = preload("res://test/fixtures/responsive_viewport_fixture.gd")

var queue: TurnQueue
var manager: BattleManager
var actors: Array[BattleCombatant] = []


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


func _enemy(actor_name: String) -> EnemyCombatant:
	var actor := EnemyCombatant.new()
	actor.setup_base(ActorStats.new(), BattleCombatant.Faction.ENEMY)
	actor.actor_name = actor_name
	actors.append(actor)
	return actor


func _hero(actor_name: String, icon: Texture2D = null, color := Color.WHITE) -> HeroCombatant:
	var actor := HeroCombatant.new()
	actor.setup_base(ActorStats.new(), BattleCombatant.Faction.HERO)
	actor.actor_name = actor_name
	var definition := RoleDefinition.new()
	definition.icon = icon
	definition.color = color
	var role := RoleData.new()
	role.source_definition = definition
	actor.loaded_roles = [role]
	actor.current_role_index = 0
	actors.append(actor)
	return actor


func _projection(active: BattleCombatant, count: int, alternate: BattleCombatant = null) -> Array:
	var result: Array = [{"actor": active, "ticks_needed": 0}]
	for index in range(1, count):
		var actor := alternate if alternate and index % 2 == 1 else active
		result.append({"actor": actor, "ticks_needed": index * 5})
	return result


func test_display_projection_publishes_active_plus_twenty_future_entries() -> void:
	var hero := _hero("Asher")
	var enemy := _enemy("Scout Drone A")
	for index in 2:
		var actor := [hero, enemy][index] as BattleCombatant
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


func test_real_queue_uses_one_uniform_scrollable_list() -> void:
	var icon := GradientTexture2D.new()
	var hero := _hero("Asher", icon, Color("56e5ff"))
	var enemy := _enemy("Scout Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 31},
		{"actor": hero, "ticks_needed": 50},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame

	assert_false(queue.has_node("ActiveName"))
	assert_false(queue.has_node("ActiveSlot"))
	assert_eq(queue.queue_items.size(), 3)
	for item: ActorQueue in queue.queue_items:
		assert_same(item.get_parent(), queue.queue_content)
		assert_eq(item.size, Vector2(72, 72))
	assert_true(queue.queue_items[0].gauge._is_current)
	assert_false(queue.queue_items[1].gauge._is_current)
	assert_eq(queue.queue_items[2].occurrence_index, 1)


func test_queue_uses_role_color_archivo_and_faction_presentation() -> void:
	var icon := GradientTexture2D.new()
	var hero := _hero("Echo", icon, Color("4f6fff"))
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 40},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame

	assert_same(queue.queue_items[0].role_icon.texture, icon)
	assert_eq(queue.queue_items[0].role_icon.self_modulate, Color("4f6fff"))
	assert_eq(queue.queue_items[1].enemy_label.text, "AD A")
	assert_same(queue.queue_items[1].enemy_label.get_theme_font("font"), ARCHIVO)
	assert_eq(
		queue.queue_items[1].enemy_label.get_theme_color("font_color"),
		CTBGauge.ENEMY_COLOR,
	)
	var hero_style := queue.queue_items[0].interior.get_theme_stylebox("panel") as StyleBoxFlat
	var enemy_style := queue.queue_items[1].interior.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(hero_style.bg_color, ActorQueue.HERO_INTERIOR_COLOR)
	assert_eq(enemy_style.bg_color, ActorQueue.ENEMY_INTERIOR_COLOR)
	assert_eq(hero_style.bg_color.a, 1.0)
	assert_eq(enemy_style.bg_color.a, 1.0)
	assert_ne(hero_style, enemy_style)


func test_current_action_ends_before_queue_rail_at_reference_viewport() -> void:
	var reference_viewport := Control.new()
	reference_viewport.size = Vector2(1920, 1080)
	add_child_autofree(reference_viewport)
	var battle := BATTLE_SCENE.instantiate() as BattleScene
	reference_viewport.add_child(battle)
	await get_tree().process_frame
	assert_eq(battle.size, Vector2(1920, 1080), "test uses the authored reference viewport")
	var current_action := battle.get_node("UI/CurrentAction") as Control
	var turn_queue := battle.get_node("UI/TurnQueue") as Control
	var current_action_right := current_action.global_position.x + current_action.size.x

	assert_lt(
		current_action_right,
		turn_queue.global_position.x,
		"the action panel ends before the queue rail",
	)


func test_rail_allocation_fully_exposes_eight_queue_cards_at_acceptance_sizes() -> void:
	for window_size in [Vector2i(1920, 1080), Vector2i(1280, 800)]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(ResponsiveFixture.logical_size_for(window_size))
		add_child_autofree(viewport)
		var battle := BATTLE_SCENE.instantiate() as BattleScene
		viewport.add_child(battle)
		battle.apply_display_profile(
			DisplayProfileService.profile_for(window_size),
			window_size,
			viewport.size,
		)
		await get_tree().process_frame
		var viewport_queue := battle.get_node("UI/TurnQueue") as TurnQueue
		assert_gte(viewport_queue.queue_scroll.size.y, float(8 * 72 + 7 * 8))
		assert_eq(
			viewport_queue.queue_scroll.horizontal_scroll_mode,
			ScrollContainer.SCROLL_MODE_DISABLED,
		)


func test_rail_background_and_scrollbar_stay_inside_queue() -> void:
	var style := queue.rail_background.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.bg_color, Color(0, 0, 0, 0.90))
	assert_eq(style.corner_radius_top_left, 18)
	assert_eq(style.corner_radius_top_right, 18)
	assert_eq(style.corner_radius_bottom_left, 18)
	assert_eq(style.corner_radius_bottom_right, 18)

	var hero := _hero("Asher")
	queue._on_turn_order_updated(_projection(hero, 21), BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	var bar: VScrollBar = queue.queue_scroll.get_v_scroll_bar()
	assert_lte(bar.global_position.x + bar.size.x, queue.global_position.x + queue.size.x - 6.0)
	assert_eq(bar.modulate.a, 0.0)
	queue.queue_scroll.scroll_vertical = 80
	assert_eq(bar.modulate.a, 1.0)
	queue.queue_scroll.scroll_vertical = 0
	assert_eq(bar.modulate.a, 0.0)


func test_refresh_preserves_and_clamps_scroll() -> void:
	var hero_a := _hero("Asher")
	var hero_b := _hero("Bell")
	queue._on_turn_order_updated(
		_projection(hero_a, 21, hero_b), BattleManager.TurnOrderUpdate.REFRESH
	)
	await get_tree().process_frame
	queue.queue_scroll.scroll_vertical = 160
	queue._on_turn_order_updated(
		_projection(hero_a, 21, hero_b), BattleManager.TurnOrderUpdate.REFRESH
	)
	await get_tree().process_frame
	assert_eq(queue.queue_scroll.scroll_vertical, 160)
	queue.queue_scroll.scroll_vertical = queue._max_future_scroll()
	queue._on_turn_order_updated(
		_projection(hero_a, 3, hero_b), BattleManager.TurnOrderUpdate.REFRESH
	)
	await get_tree().process_frame
	assert_eq(queue.queue_scroll.scroll_vertical, queue._max_future_scroll())


func test_preview_and_refresh_preserve_scroll_but_commit_and_advance_reset() -> void:
	var hero := _hero("Asher")
	var projection := _projection(hero, 21)
	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	queue.queue_scroll.scroll_vertical = 160

	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.PREVIEW)
	await get_tree().process_frame
	assert_eq(queue.queue_scroll.scroll_vertical, 160)
	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	assert_eq(queue.queue_scroll.scroll_vertical, 160)

	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.COMMIT)
	assert_eq(queue.queue_scroll.scroll_vertical, 0)
	queue.queue_scroll.scroll_vertical = 160
	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.ADVANCE)
	assert_eq(queue.queue_scroll.scroll_vertical, 0)

	queue.queue_scroll.scroll_vertical = 160
	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.PREVIEW)
	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.COMMIT)
	await get_tree().process_frame
	assert_eq(queue.queue_scroll.scroll_vertical, 0, "stale preview cannot undo commit reset")

	queue.queue_scroll.scroll_vertical = 160
	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.PREVIEW)
	queue._on_turn_order_updated(projection, BattleManager.TurnOrderUpdate.ADVANCE)
	await get_tree().process_frame
	assert_eq(queue.queue_scroll.scroll_vertical, 0, "stale preview cannot undo advance reset")


func test_right_stick_scroll_does_not_change_combat_selection() -> void:
	var hero := _hero("Asher")
	var enemy := _enemy("Scout Drone")
	queue._on_turn_order_updated(
		_projection(hero, 21, enemy), BattleManager.TurnOrderUpdate.REFRESH
	)
	await get_tree().process_frame
	var selected_action := Action.new()
	manager.current_action = selected_action
	enemy.is_valid_target = true

	queue.scroll_future_by_axis(1.0, 0.1)

	assert_gt(queue.queue_scroll.scroll_vertical, 0)
	assert_same(manager.current_action, selected_action)
	assert_true(enemy.is_valid_target)


func test_right_stick_scroll_accumulates_fractional_pixels_across_small_frames() -> void:
	var hero := _hero("Asher")
	queue._on_turn_order_updated(_projection(hero, 21), BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame

	for frame in 10:
		queue.scroll_future_by_axis(1.0, 0.001)
	var small_frame_scroll: int = queue.queue_scroll.scroll_vertical
	queue.queue_scroll.scroll_vertical = 0
	queue.scroll_future_by_axis(1.0, 0.01)

	assert_eq(small_frame_scroll, 7)
	assert_eq(queue.queue_scroll.scroll_vertical, small_frame_scroll)


func test_right_stick_fraction_resets_across_dead_zone_and_direction_change() -> void:
	var hero := _hero("Asher")
	queue._on_turn_order_updated(_projection(hero, 21), BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame

	queue.scroll_future_by_axis(1.0, 0.0005)
	queue.scroll_future_by_axis(0.0, 0.1)
	queue.scroll_future_by_axis(1.0, 0.001)
	assert_eq(queue.queue_scroll.scroll_vertical, 0)

	queue.scroll_future_by_axis(0.0, 0.1)
	queue.queue_scroll.scroll_vertical = 10
	queue.scroll_future_by_axis(1.0, 0.0005)
	queue.scroll_future_by_axis(-1.0, 0.001)
	assert_eq(queue.queue_scroll.scroll_vertical, 10)


func test_overflow_fade_tracks_scroll_extent() -> void:
	var hero := _hero("Asher")
	queue._on_turn_order_updated(_projection(hero, 21), BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	queue._update_overflow_fade()
	assert_true(queue.overflow_fade.visible)
	queue.queue_scroll.scroll_vertical = queue._max_future_scroll()
	queue._update_overflow_fade()
	assert_false(queue.overflow_fade.visible)
	queue._on_turn_order_updated(_projection(hero, 3), BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	queue._update_overflow_fade()
	assert_false(queue.overflow_fade.visible)


func test_clear_hides_overflow_fade_before_layout_recalculates() -> void:
	var hero := _hero("Asher")
	queue._on_turn_order_updated(_projection(hero, 21), BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	queue._update_overflow_fade()
	assert_true(queue.overflow_fade.visible)

	queue._on_turn_order_updated([], BattleManager.TurnOrderUpdate.REFRESH)

	assert_false(queue.overflow_fade.visible)


func test_preview_reuses_occurrences_and_visually_swaps_positions() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 30},
		{"actor": hero, "ticks_needed": 40},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	var old_items := queue.queue_items.duplicate()
	var enemy_item := old_items[1] as ActorQueue
	var future_hero_item := old_items[2] as ActorQueue

	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": hero, "ticks_needed": 20},
		{"actor": enemy, "ticks_needed": 35},
	], BattleManager.TurnOrderUpdate.PREVIEW)

	assert_same(queue.queue_items[1], future_hero_item)
	assert_same(queue.queue_items[2], enemy_item)
	assert_true(future_hero_item._move_tween != null)
	assert_true(enemy_item._move_tween != null)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION + 0.05).timeout
	assert_eq(future_hero_item.position, queue._target_position(1))
	assert_eq(enemy_item.position, queue._target_position(2))


func test_advance_slides_consumed_occurrence_left_above_promoted_item() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": hero, "ticks_needed": 20},
		{"actor": enemy, "ticks_needed": 40},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	var outgoing := queue.queue_items[0]
	var promoted := queue.queue_items[1]
	var outgoing_start_x := outgoing.global_position.x

	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 20},
	], BattleManager.TurnOrderUpdate.ADVANCE)

	assert_true(outgoing._exit_tween != null)
	assert_same(outgoing.get_parent(), queue.exit_layer)
	assert_gt(queue.exit_layer.z_index, queue.queue_scroll.z_index)
	assert_same(queue.queue_items[0], promoted)
	assert_eq(queue.queue_scroll.scroll_vertical, 0)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION * 0.5).timeout
	assert_lt(outgoing.global_position.x, outgoing_start_x)
	assert_lt(outgoing.modulate.a, 1.0)
	assert_lt(outgoing.global_position.x + outgoing.size.x, promoted.global_position.x)
	assert_gt(promoted.position.y, queue._target_position(0).y)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION * 0.5 + 0.05).timeout
	assert_false(is_instance_valid(outgoing))
	assert_eq(promoted.position, queue._target_position(0))
	assert_true(promoted.gauge._is_current)


func test_preview_removal_fades_in_place_inside_queue_content() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 30},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	var removed := queue.queue_items[1]
	var start_position := removed.position

	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
	], BattleManager.TurnOrderUpdate.PREVIEW)

	assert_same(removed.get_parent(), queue.queue_content)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION * 0.5).timeout
	assert_eq(removed.position, start_position)
	assert_lt(removed.modulate.a, 1.0)


func test_rapid_preview_replaces_position_and_gauge_targets() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated(_projection(hero, 8, enemy), BattleManager.TurnOrderUpdate.REFRESH)
	queue._on_turn_order_updated(_projection(enemy, 8, hero), BattleManager.TurnOrderUpdate.PREVIEW)
	queue._on_turn_order_updated(_projection(hero, 8, enemy), BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION + 0.05).timeout

	for index in queue.queue_items.size():
		var item := queue.queue_items[index]
		assert_eq(item.position, queue._target_position(index))
		assert_eq(item.gauge.displayed_ticks, float(index * 5))


func test_preview_restore_cancels_exit_and_reuses_same_control() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 30},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	var enemy_item := queue.queue_items[1]

	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
	], BattleManager.TurnOrderUpdate.PREVIEW)
	assert_true(enemy_item._exit_tween != null)
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 35},
	], BattleManager.TurnOrderUpdate.REFRESH)

	assert_same(queue.queue_items[1], enemy_item)
	assert_eq(queue.queue_content.get_child_count(), 2)
	assert_null(enemy_item._exit_tween)
	assert_eq(enemy_item.modulate.a, 1.0)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION + 0.05).timeout
	assert_true(is_instance_valid(enemy_item))
	assert_eq(queue.queue_content.get_child_count(), 2)


func test_empty_projection_synchronously_clears_in_flight_exits() -> void:
	var hero := _hero("Echo")
	var enemy := _enemy("Attack Drone A")
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 0},
		{"actor": enemy, "ticks_needed": 30},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame
	var enemy_item := queue.queue_items[1]
	queue._on_turn_order_updated([
		{"actor": hero, "ticks_needed": 10},
	], BattleManager.TurnOrderUpdate.PREVIEW)
	assert_true(enemy_item._exit_tween != null)

	queue._on_turn_order_updated([], BattleManager.TurnOrderUpdate.REFRESH)

	assert_true(queue.queue_items.is_empty())
	assert_eq(queue.queue_content.get_child_count(), 0)
	assert_false(is_instance_valid(enemy_item))
	assert_eq(queue.queue_scroll.scroll_vertical, 0)
	assert_eq(queue.queue_scroll.get_v_scroll_bar().modulate.a, 0.0)
	assert_false(queue.overflow_fade.visible)
	await get_tree().create_timer(ActorQueue.ANIMATION_DURATION + 0.05).timeout
	assert_eq(queue.queue_content.get_child_count(), 0)
