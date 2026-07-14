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


func test_task_five_compatibility_calls_cannot_drive_or_reveal_pointer() -> void:
	var cursor := CursorScript.new()
	add_child_autofree(cursor)
	var target := Button.new()
	target.position = Vector2(100, 80)
	target.size = Vector2(40, 20)
	add_child_autofree(target)
	var initial_position := cursor.position
	var physical_mouse := cursor.get_viewport().get_mouse_position()
	cursor.set_focus_target(target, CursorScript.CursorState.INTERACT)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2(900, 700), true)
	assert_false(cursor.visible)
	assert_eq(cursor.position, initial_position)
	assert_eq(cursor.get_viewport().get_mouse_position(), physical_mouse)
	cursor.set_world_target(target, CursorScript.CursorState.TARGET)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.FREE, Vector2(500, 400), true)
	assert_false(cursor.visible)
	assert_eq(cursor.position, initial_position)
	assert_eq(cursor.get_viewport().get_mouse_position(), physical_mouse)
