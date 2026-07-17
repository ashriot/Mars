extends GutTest

const CursorScript = preload("res://src/ui/navigation/navigation_cursor.gd")


func _target_at(position: Vector2, target_size: Vector2) -> Control:
	var target := Control.new()
	target.focus_mode = Control.FOCUS_ALL
	target.position = position
	target.size = target_size
	add_child_autofree(target)
	return target


func _assert_cursor_clears_readable_center(cursor: NavigationCursor, target: Control) -> void:
	var cursor_rect := Rect2(cursor.position, cursor._effective_cursor_size())
	var target_rect := target.get_global_rect()
	var readable_center := Rect2(target_rect.position + target_rect.size * 0.25, target_rect.size * 0.5)
	assert_false(
		cursor_rect.intersects(readable_center, false),
		"cursor rectangle must not overlap the target's readable center",
	)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	assert_gte(cursor.position.x, cursor.VIEWPORT_MARGIN)
	assert_gte(cursor.position.y, cursor.VIEWPORT_MARGIN)
	assert_lte(cursor_rect.end.x, viewport_size.x - cursor.VIEWPORT_MARGIN)
	assert_lte(cursor_rect.end.y, viewport_size.y - cursor.VIEWPORT_MARGIN)


func test_scan_pointer_starts_hidden_with_arrow_texture() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	assert_false(cursor.visible)
	assert_eq(cursor.texture.resource_path.get_file(), "pointer_c.svg")
	assert_eq(cursor.scale, Vector2.ONE)


func test_show_at_screen_position_moves_and_shows_without_touching_mouse() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var physical_mouse := cursor.get_viewport().get_mouse_position()
	cursor.show_at_screen_position(Vector2(320, 180))
	assert_eq(cursor.position, Vector2(320, 180))
	assert_true(cursor.visible)
	assert_eq(cursor.get_viewport().get_mouse_position(), physical_mouse)
	assert_eq(cursor.scale, Vector2.ONE)
	assert_eq(cursor._effective_cursor_size(), Vector2(32, 32))
	cursor.hide_pointer()
	assert_false(cursor.visible)


func test_hub_target_uses_east_hand_at_upper_left_and_preserves_physical_mouse() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := _target_at(Vector2(100, 80), Vector2(240, 60))
	var physical_mouse := get_viewport().get_mouse_position()
	cursor.track_hub_target(target, false)
	assert_true(cursor.visible)
	assert_eq(cursor.texture.resource_path.get_file(), "hand_point_e.svg")
	assert_eq(cursor.scale, Vector2(2, 2))
	assert_eq(cursor._effective_cursor_size(), Vector2(64, 64))
	assert_eq(cursor.position, Vector2(44, 80))
	assert_eq(get_viewport().get_mouse_position(), physical_mouse)


func test_hub_hand_drifts_left_slowly_then_returns_quickly() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := _target_at(Vector2(100, 80), Vector2(240, 60))
	cursor.track_hub_target(target, false)
	var resting_position := cursor.position

	cursor._breath_tween.custom_step(0.65)
	var away_position := cursor.position
	assert_lt(away_position.x, resting_position.x)
	assert_almost_eq(away_position.y, resting_position.y, 0.01)
	assert_almost_eq(away_position.distance_to(resting_position), 6.0, 0.1)

	cursor._breath_tween.custom_step(0.16)
	assert_almost_eq(cursor.position.x, resting_position.x, 0.01)
	assert_almost_eq(cursor.position.y, resting_position.y, 0.01)


func test_focus_move_pauses_breathing_then_restarts_at_latest_target() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var first := _target_at(Vector2(40, 40), Vector2(100, 40))
	var latest := _target_at(Vector2(400, 300), Vector2(100, 40))
	cursor.track_hub_target(first, false)
	assert_true(cursor._breath_tween.is_running())

	cursor.track_hub_target(latest, true)
	assert_true(cursor._breath_tween == null or not cursor._breath_tween.is_running())
	cursor._move_tween.custom_step(0.07)
	cursor._move_tween.custom_step(0.001)

	assert_eq(cursor.position, cursor._hub_position(latest))
	assert_true(cursor._breath_tween.is_running())


func test_narrow_right_edge_target_keeps_cursor_out_of_readable_center() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var target := _target_at(viewport_size - Vector2(24, 60), Vector2(20, 56))

	cursor.track_hub_target(target, false)

	_assert_cursor_clears_readable_center(cursor, target)


func test_narrow_bottom_edge_target_keeps_cursor_out_of_readable_center() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var target := _target_at(viewport_size - Vector2(60, 24), Vector2(56, 20))

	cursor.track_hub_target(target, false)

	_assert_cursor_clears_readable_center(cursor, target)


func test_bottom_right_corner_target_keeps_cursor_out_of_readable_center() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var target := _target_at(viewport_size - Vector2(52, 52), Vector2(48, 48))

	cursor.track_hub_target(target, false)

	_assert_cursor_clears_readable_center(cursor, target)


func test_moving_target_crosses_edge_avoidance_boundary_deterministically() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var interior_position := viewport_size - Vector2(260, 260)
	var target := _target_at(interior_position, Vector2(48, 48))
	cursor.track_hub_target(target, false)
	var interior_cursor_position := cursor.position
	_assert_cursor_clears_readable_center(cursor, target)

	target.position = viewport_size - Vector2(52, 52)
	cursor._process(0.0)
	var edge_cursor_position := cursor.position
	_assert_cursor_clears_readable_center(cursor, target)
	assert_ne(edge_cursor_position, interior_cursor_position, "edge crossing selects a clearing fallback")
	cursor._process(0.0)
	assert_eq(cursor.position, edge_cursor_position, "fixed edge placement does not oscillate between candidates")

	target.position = interior_position
	cursor._process(0.0)
	_assert_cursor_clears_readable_center(cursor, target)
	assert_eq(cursor.position, interior_cursor_position, "reverse crossing restores the exact upper-left hand anchor")


func test_hub_target_clamps_complete_cursor_inside_viewport() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.focus_mode = Control.FOCUS_ALL
	target.position = Vector2(1130, 650)
	target.size = Vector2(145, 145)
	add_child_autofree(target)
	cursor.track_hub_target(target, false)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var cursor_size := cursor._effective_cursor_size()
	assert_lte(cursor.position.x + cursor_size.x, viewport_size.x - cursor.VIEWPORT_MARGIN)
	assert_lte(cursor.position.y + cursor_size.y, viewport_size.y - cursor.VIEWPORT_MARGIN)


func test_new_hub_target_replaces_in_flight_cursor_tween() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var first := Control.new()
	var second := Control.new()
	first.focus_mode = Control.FOCUS_ALL
	second.focus_mode = Control.FOCUS_ALL
	first.position = Vector2(40, 40)
	second.position = Vector2(400, 300)
	first.size = Vector2(100, 40)
	second.size = Vector2(100, 40)
	add_child_autofree(first)
	add_child_autofree(second)
	cursor.track_hub_target(first, false)
	cursor.track_hub_target(second, true)
	var replaced: Tween = cursor._move_tween
	cursor.track_hub_target(first, true)
	assert_false(replaced.is_valid())
	assert_same(cursor._hub_target.get_ref(), first)


func test_hub_cursor_tween_tracks_live_target_and_finishes_at_seventy_ms() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var first := _target_at(Vector2(40, 40), Vector2(100, 40))
	var target := _target_at(Vector2(400, 300), Vector2(100, 40))
	cursor.track_hub_target(first, false)
	cursor.track_hub_target(target, true)
	var initial_destination := cursor._hub_position(target)

	cursor._move_tween.custom_step(0.03)
	assert_ne(cursor.position, initial_destination, "cursor remains in flight before 70 ms")
	target.position += Vector2(120, 35)
	var live_destination := cursor._hub_position(target)
	cursor._move_tween.custom_step(0.04)

	assert_eq(cursor.position, live_destination, "completion uses the live target anchor")


func test_replaced_hub_cursor_tween_finishes_at_latest_target() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var origin := _target_at(Vector2(40, 40), Vector2(100, 40))
	var replaced := _target_at(Vector2(300, 200), Vector2(100, 40))
	var latest := _target_at(Vector2(600, 360), Vector2(100, 40))
	cursor.track_hub_target(origin, false)
	cursor.track_hub_target(replaced, true)
	cursor._move_tween.custom_step(0.025)
	cursor.track_hub_target(latest, true)
	var latest_destination := cursor._hub_position(latest)

	cursor._move_tween.custom_step(0.03)
	assert_ne(cursor.position, latest_destination, "replacement tween remains in flight before 70 ms")
	cursor._move_tween.custom_step(0.04)

	assert_eq(cursor.position, latest_destination)


func test_scan_position_clears_hub_tracking_without_changing_scan_api() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.focus_mode = Control.FOCUS_ALL
	target.size = Vector2(100, 40)
	add_child_autofree(target)
	cursor.track_hub_target(target, false)
	cursor.show_at_screen_position(Vector2(320, 180))
	assert_false(cursor.is_tracking_hub_target())
	assert_eq(cursor.position, Vector2(320, 180))
	assert_eq(cursor.texture.resource_path.get_file(), "pointer_c.svg")
	assert_eq(cursor.scale, Vector2.ONE)
	assert_true(cursor._breath_tween == null or not cursor._breath_tween.is_running())


func test_tracked_hub_button_clears_when_disabled() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var first := Control.new()
	first.focus_mode = Control.FOCUS_ALL
	first.size = Vector2(100, 40)
	var target := Button.new()
	target.position = Vector2(400, 300)
	target.size = Vector2(100, 40)
	add_child_autofree(first)
	add_child_autofree(target)
	cursor.track_hub_target(first, false)
	cursor.track_hub_target(target, true)
	assert_true(cursor.is_tracking_hub_target())
	assert_true(cursor._move_tween.is_running())
	var physical_mouse := get_viewport().get_mouse_position()

	target.disabled = true
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(cursor.is_tracking_hub_target())
	assert_false(cursor.visible)
	assert_eq(get_viewport().get_mouse_position(), physical_mouse)


func test_tracked_hub_control_clears_when_focus_is_disabled() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.focus_mode = Control.FOCUS_ALL
	target.size = Vector2(100, 40)
	add_child_autofree(target)
	cursor.track_hub_target(target, false)
	assert_true(cursor.is_tracking_hub_target())

	target.focus_mode = Control.FOCUS_NONE
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(cursor.is_tracking_hub_target())
	assert_false(cursor.visible)


func test_invalid_hub_target_does_not_clear_external_scan_pointer() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Button.new()
	target.disabled = true
	add_child_autofree(target)
	cursor.show_at_screen_position(Vector2(320, 180))

	cursor.track_hub_target(target, false)

	assert_false(cursor.is_tracking_hub_target())
	assert_true(cursor.visible)
	assert_eq(cursor.position, Vector2(320, 180))
