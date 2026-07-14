extends GutTest

const CursorScript = preload("res://src/ui/navigation/navigation_cursor.gd")

class TestCursor extends NavigationCursor:
	static var last_mode := Input.MOUSE_MODE_VISIBLE
	var set_modes: Array[Input.MouseMode] = []
	var warped_positions: Array[Vector2] = []
	var expected_positions_at_warp: Array[Vector2] = []

	func _set_mouse_mode(mode: Input.MouseMode) -> void:
		last_mode = mode
		set_modes.append(mode)

	func _warp_mouse(position: Vector2) -> void:
		warped_positions.append(position)
		expected_positions_at_warp.append(InputManager._expected_warp_position)


class ViewportWarpCursor extends NavigationCursor:
	var warped_viewports: Array[Viewport] = []
	var warped_positions: Array[Vector2] = []

	func _warp_viewport_mouse(viewport: Viewport, position: Vector2) -> void:
		warped_viewports.append(viewport)
		warped_positions.append(position)


func test_cursor_forces_os_pointer_visible_by_default() -> void:
	TestCursor.last_mode = Input.MOUSE_MODE_HIDDEN
	var cursor := TestCursor.new()
	add_child(cursor)
	assert_eq(cursor.set_modes, [Input.MOUSE_MODE_VISIBLE])
	assert_eq(TestCursor.last_mode, Input.MOUSE_MODE_VISIBLE)
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


func test_snapped_target_warps_through_owning_viewport_coordinates() -> void:
	var cursor := ViewportWarpCursor.new()
	add_child_autofree(cursor)
	var target := Control.new()
	target.position = Vector2(200, 120)
	target.size = Vector2(80, 40)
	add_child_autofree(target)
	cursor.set_focus_target(target)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_eq(cursor.warped_viewports, [cursor.get_viewport()])
	assert_eq(cursor.warped_positions, [Vector2(240, 140)])


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


func test_explicit_screen_position_stays_visible_without_focus_target() -> void:
	var cursor := TestCursor.new()
	add_child_autofree(cursor)
	cursor.show_at_screen_position(Vector2(320, 180))
	assert_true(cursor.is_screen_position_active())
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO)
	assert_true(cursor.visible)
	assert_eq(cursor.position, Vector2(320, 180))
	assert_null(cursor._target)
	assert_eq(cursor.set_modes.back(), Input.MOUSE_MODE_HIDDEN)


func test_clear_target_exits_explicit_screen_position_mode() -> void:
	var cursor := TestCursor.new()
	add_child_autofree(cursor)
	cursor.show_at_screen_position(Vector2(50, 60))
	cursor.clear_target()
	assert_false(cursor.is_screen_position_active())
	assert_false(cursor.visible)
	assert_eq(cursor.set_modes.back(), Input.MOUSE_MODE_VISIBLE)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO)
	assert_false(cursor.visible)


func test_focus_and_world_targets_replace_explicit_screen_position_ownership() -> void:
	var cursor := TestCursor.new()
	add_child_autofree(cursor)
	var target := Button.new()
	add_child_autofree(target)
	cursor.show_at_screen_position(Vector2(50, 60))
	cursor.set_focus_target(target)
	assert_false(cursor.is_screen_position_active())
	assert_same(cursor._target, target)
	cursor.show_at_screen_position(Vector2(70, 80))
	cursor.set_world_target(target)
	assert_false(cursor.is_screen_position_active())
	assert_same(cursor._target, target)


func test_freeing_explicit_screen_cursor_restores_os_pointer() -> void:
	TestCursor.last_mode = Input.MOUSE_MODE_VISIBLE
	var cursor := TestCursor.new()
	add_child(cursor)
	cursor.show_at_screen_position(Vector2(50, 60))
	assert_eq(TestCursor.last_mode, Input.MOUSE_MODE_HIDDEN)
	cursor.free()
	assert_eq(TestCursor.last_mode, Input.MOUSE_MODE_VISIBLE)


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
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_eq(cursor.warped_positions, [Vector2(70, 50)])
	cursor.set_focus_target(second)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_eq(cursor.warped_positions, [Vector2(70, 50), Vector2(220, 90)])
	cursor.update_position_for_behavior(InputManager.CursorBehavior.FREE, Vector2(10, 10), true)
	cursor.set_focus_target(second)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_eq(cursor.warped_positions, [Vector2(70, 50), Vector2(220, 90), Vector2(220, 90)])


func test_same_frame_mouse_click_then_snapped_input_resets_warp_dedupe_before_process() -> void:
	var saved_mode := InputManager._active_mode
	var saved_behavior := InputManager._cursor_behavior
	var saved_expected_position := InputManager._expected_warp_position
	var saved_expected_deadline := InputManager._expected_warp_deadline_ms
	var cursor := TestCursor.new()
	add_child(cursor)
	var target := Button.new()
	target.position = Vector2(20, 30)
	target.size = Vector2(100, 40)
	add_child(target)
	cursor.set_focus_target(target)
	InputManager._set_cursor_behavior(InputManager.CursorBehavior.SNAPPED)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_eq(cursor.warped_positions, [Vector2(70, 50)])
	var mouse_position := Vector2(10, 10)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	InputManager._input(click)
	assert_eq(InputManager.get_cursor_behavior(), InputManager.CursorBehavior.FREE)
	var navigation := InputEventKey.new()
	navigation.physical_keycode = KEY_D
	navigation.pressed = true
	InputManager._input(navigation)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.KEYBOARD_MOUSE)
	assert_eq(InputManager.get_cursor_behavior(), InputManager.CursorBehavior.SNAPPED)
	cursor.update_position_for_behavior(InputManager.get_cursor_behavior(), mouse_position, true)
	assert_eq(cursor.warped_positions, [Vector2(70, 50), Vector2(70, 50)])
	cursor.update_position_for_behavior(InputManager.get_cursor_behavior(), mouse_position, true)
	assert_eq(cursor.warped_positions, [Vector2(70, 50), Vector2(70, 50)])
	click.pressed = false
	InputManager._input(click)
	target.free()
	cursor.free()
	InputManager._active_mode = saved_mode
	InputManager._cursor_behavior = saved_behavior
	InputManager._expected_warp_position = saved_expected_position
	InputManager._expected_warp_deadline_ms = saved_expected_deadline


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


func test_clear_target_resets_default_and_specialized_controls_can_set_state_again() -> void:
	var cursor = CursorScript.new()
	add_child_autofree(cursor)
	var target := Button.new()
	add_child_autofree(target)
	cursor.set_focus_target(target, CursorScript.CursorState.TARGET)
	cursor.clear_target()
	assert_null(cursor._target)
	assert_eq(cursor._state, CursorScript.CursorState.DEFAULT)
	assert_eq(cursor.texture.resource_path.get_file(), "pointer_c.svg")
	cursor.set_focus_target(target, CursorScript.CursorState.CAN_GRAB)
	assert_eq(cursor._state, CursorScript.CursorState.CAN_GRAB)
	assert_eq(cursor.texture.resource_path.get_file(), "hand_open.svg")


func test_off_tree_target_clears_without_warping() -> void:
	var cursor := TestCursor.new()
	add_child_autofree(cursor)
	var target := Button.new()
	cursor.set_focus_target(target)
	cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_false(cursor.visible)
	assert_true(cursor.warped_positions.is_empty())
	target.free()
