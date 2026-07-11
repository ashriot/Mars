extends GutTest

const CursorScript = preload("res://src/ui/navigation/navigation_cursor.gd")


func test_cursor_states_resolve_all_approved_textures() -> void:
	var cursor = CursorScript.new()
	add_child_autofree(cursor)
	for state in CursorScript.CursorState.values():
		cursor.set_cursor_state(state)
		assert_not_null(cursor.texture, "state %s has a texture" % state)


func test_controller_target_uses_control_center_and_anchor_metadata() -> void:
	var cursor = CursorScript.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.position = Vector2(20, 30)
	target.size = Vector2(100, 40)
	add_child_autofree(target)
	cursor.set_focus_target(target)
	cursor.update_position_for_mode(InputManager.InputMode.CONTROLLER, Vector2.ZERO, true)
	assert_eq(cursor.position, Vector2(70, 50))
	target.set_meta("cursor_anchor", Vector2(10, 12))
	cursor.update_position_for_mode(InputManager.InputMode.CONTROLLER, Vector2.ZERO, true)
	assert_eq(cursor.position, Vector2(30, 42))


func test_mouse_mode_uses_injected_viewport_coordinates_without_warping() -> void:
	var cursor = CursorScript.new()
	add_child_autofree(cursor)
	cursor.update_position_for_mode(InputManager.InputMode.MOUSE, Vector2(321, 123), true)
	assert_eq(cursor.position, Vector2(321, 123))


func test_hidden_or_disabled_focus_target_clears_safely() -> void:
	var cursor = CursorScript.new()
	add_child_autofree(cursor)
	var target := Button.new()
	add_child_autofree(target)
	cursor.set_focus_target(target)
	target.disabled = true
	cursor.update_position_for_mode(InputManager.InputMode.CONTROLLER, Vector2.ZERO, true)
	assert_false(cursor.visible)
	target.disabled = false
	target.hide()
	cursor.set_focus_target(target)
	cursor.update_position_for_mode(InputManager.InputMode.CONTROLLER, Vector2.ZERO, true)
	assert_false(cursor.visible)
