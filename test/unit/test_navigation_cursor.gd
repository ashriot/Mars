extends GutTest

const CursorScript = preload("res://src/ui/navigation/navigation_cursor.gd")


func test_scan_pointer_starts_hidden_with_arrow_texture() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	assert_false(cursor.visible)
	assert_eq(cursor.texture.resource_path.get_file(), "pointer_c.svg")


func test_show_at_screen_position_moves_and_shows_without_touching_mouse() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var physical_mouse := cursor.get_viewport().get_mouse_position()
	cursor.show_at_screen_position(Vector2(320, 180))
	assert_eq(cursor.position, Vector2(320, 180))
	assert_true(cursor.visible)
	assert_eq(cursor.get_viewport().get_mouse_position(), physical_mouse)
	cursor.hide_pointer()
	assert_false(cursor.visible)


func test_hub_target_uses_lower_right_anchor_and_preserves_physical_mouse() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.position = Vector2(100, 80)
	target.size = Vector2(240, 60)
	add_child_autofree(target)
	var physical_mouse := get_viewport().get_mouse_position()
	cursor.track_hub_target(target, false)
	assert_true(cursor.visible)
	assert_eq(cursor.position, Vector2(346, 146))
	assert_eq(get_viewport().get_mouse_position(), physical_mouse)


func test_hub_target_clamps_complete_cursor_inside_viewport() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.position = Vector2(1130, 650)
	target.size = Vector2(145, 145)
	add_child_autofree(target)
	cursor.track_hub_target(target, false)
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	assert_lte(cursor.position.x + cursor.size.x, viewport_size.x - cursor.VIEWPORT_MARGIN)
	assert_lte(cursor.position.y + cursor.size.y, viewport_size.y - cursor.VIEWPORT_MARGIN)


func test_new_hub_target_replaces_in_flight_cursor_tween() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var first := Control.new()
	var second := Control.new()
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


func test_scan_position_clears_hub_tracking_without_changing_scan_api() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.size = Vector2(100, 40)
	add_child_autofree(target)
	cursor.track_hub_target(target, false)
	cursor.show_at_screen_position(Vector2(320, 180))
	assert_false(cursor.is_tracking_hub_target())
	assert_eq(cursor.position, Vector2(320, 180))
