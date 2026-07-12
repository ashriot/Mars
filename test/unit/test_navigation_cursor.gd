extends GutTest

const CursorScript = preload("res://src/ui/navigation/navigation_cursor.gd")

class TestCursor extends NavigationCursor:
	static var last_mode := Input.MOUSE_MODE_VISIBLE
	var simulated_mouse_mode := Input.MOUSE_MODE_VISIBLE
	var warped_positions: Array[Vector2] = []
	var expected_positions_at_warp: Array[Vector2] = []

	func _get_mouse_mode() -> Input.MouseMode:
		return simulated_mouse_mode

	func _set_mouse_mode(mode: Input.MouseMode) -> void:
		simulated_mouse_mode = mode
		last_mode = mode

	func _warp_mouse(position: Vector2) -> void:
		warped_positions.append(position)
		expected_positions_at_warp.append(InputManager._expected_warp_position)


func test_cursor_hides_os_pointer_while_active_and_restores_it_on_exit() -> void:
	TestCursor.last_mode = Input.MOUSE_MODE_VISIBLE
	var cursor := TestCursor.new()
	add_child(cursor)
	assert_eq(TestCursor.last_mode, Input.MOUSE_MODE_HIDDEN)
	cursor.free()
	assert_eq(TestCursor.last_mode, Input.MOUSE_MODE_VISIBLE)


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


func test_snapped_target_uses_control_center_and_anchor_metadata() -> void:
	var cursor := TestCursor.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.position = Vector2(20, 30)
	target.size = Vector2(100, 40)
	add_child_autofree(target)
	cursor.set_focus_target(target)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_eq(cursor.position, Vector2(70, 50))
	assert_eq(cursor.warped_positions, [Vector2(70, 50)])
	assert_eq(cursor.expected_positions_at_warp, [Vector2(70, 50)])
	assert_eq(InputManager._expected_warp_position, Vector2(70, 50))
	target.set_meta("cursor_anchor", Vector2(10, 12))
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2(70, 50), true)
	assert_eq(cursor.position, Vector2(30, 42))
	assert_eq(cursor.warped_positions, [Vector2(70, 50), Vector2(30, 42)])


func test_free_behavior_continues_from_synchronized_mouse_position_with_real_delta() -> void:
	var cursor := TestCursor.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.position = Vector2(20, 30)
	target.size = Vector2(100, 40)
	add_child_autofree(target)
	cursor.set_focus_target(target)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2(10, 10), true)
	assert_eq(cursor.warped_positions, [Vector2(70, 50)])
	cursor.update_position_for_behavior(InputManager.CursorBehavior.FREE, Vector2(77, 46), true)
	assert_eq(cursor.position, Vector2(77, 46))
	assert_eq(cursor.warped_positions, [Vector2(70, 50)])


func test_same_physical_destination_does_not_repeat_warp_but_changed_target_warps_once() -> void:
	var cursor := TestCursor.new()
	add_child_autofree(cursor)
	var first := Button.new()
	first.position = Vector2(20, 30)
	first.size = Vector2(100, 40)
	add_child_autofree(first)
	var second := Button.new()
	second.position = Vector2(200, 80)
	second.size = Vector2(40, 20)
	add_child_autofree(second)
	cursor.set_focus_target(first)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_eq(cursor.warped_positions, [Vector2(70, 50)])
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2(70, 50), true)
	assert_eq(cursor.warped_positions, [Vector2(70, 50)])
	cursor.set_focus_target(second)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2(70, 50), true)
	assert_eq(cursor.warped_positions, [Vector2(70, 50), Vector2(220, 90)])


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
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_eq(cursor.position, target.get_global_transform_with_canvas().origin)


func test_freed_target_clears_safely() -> void:
	var cursor = CursorScript.new()
	add_child_autofree(cursor)
	var target := Button.new()
	add_child(target)
	cursor.set_focus_target(target)
	target.free()
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_false(cursor.visible)


func test_hidden_or_disabled_focus_target_clears_safely() -> void:
	var cursor = CursorScript.new()
	add_child_autofree(cursor)
	var target := Button.new()
	add_child_autofree(target)
	cursor.set_focus_target(target)
	target.disabled = true
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_false(cursor.visible)
	target.disabled = false
	target.hide()
	cursor.set_focus_target(target)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_false(cursor.visible)


func test_off_tree_target_clears_without_warping() -> void:
	var cursor := TestCursor.new()
	add_child_autofree(cursor)
	var target := Button.new()
	cursor.set_focus_target(target)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_false(cursor.visible)
	assert_true(cursor.warped_positions.is_empty())
	target.free()
