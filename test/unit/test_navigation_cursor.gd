extends GutTest

const CursorScript = preload("res://src/ui/navigation/navigation_cursor.gd")


func test_cursor_states_resolve_all_approved_textures() -> void:
	var cursor = CursorScript.new()
	add_child_autofree(cursor)
	var approved := {
		CursorScript.CursorState.DEFAULT: "pointer_c.svg",
		CursorScript.CursorState.INTERACT: "hand_point.svg",
		CursorScript.CursorState.CAN_GRAB: "hand_open.svg",
		CursorScript.CursorState.DRAGGING: "hand_closed.svg",
		CursorScript.CursorState.UPGRADE: "tool_hammer.svg",
		CursorScript.CursorState.DISABLED: "cursor_disabled.svg",
		CursorScript.CursorState.BUSY: "busy_circle.svg",
		CursorScript.CursorState.TARGET: "cross_small.svg",
		CursorScript.CursorState.MODIFY: "cursor_cogs.svg",
	}
	for state in approved:
		cursor.set_cursor_state(state)
		assert_eq(cursor.texture.resource_path.get_file(), approved[state])


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
	var source := FileAccess.get_file_as_string("res://src/ui/navigation/navigation_cursor.gd")
	assert_eq(source.find("warp_mouse"), -1, "cursor implementation has no OS-warp call")


func test_world_target_uses_canvas_transform() -> void:
	var cursor = CursorScript.new()
	add_child_autofree(cursor)
	var parent := Node2D.new()
	parent.position = Vector2(100, 40)
	parent.scale = Vector2(2, 2)
	add_child_autofree(parent)
	var target := Node2D.new()
	target.position = Vector2(7, 11)
	parent.add_child(target)
	cursor.set_world_target(target)
	cursor.update_position_for_mode(InputManager.InputMode.CONTROLLER, Vector2.ZERO, true)
	assert_eq(cursor.position, target.get_global_transform_with_canvas().origin)


func test_freed_target_clears_safely() -> void:
	var cursor = CursorScript.new()
	add_child_autofree(cursor)
	var target := Button.new()
	add_child(target)
	cursor.set_focus_target(target)
	target.free()
	cursor.update_position_for_mode(InputManager.InputMode.CONTROLLER, Vector2.ZERO, true)
	assert_false(cursor.visible)


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
