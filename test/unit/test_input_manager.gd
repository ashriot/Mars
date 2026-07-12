extends GutTest

const InputManagerScript := preload("res://src/singletons/input_manager.gd")

var manager: Node
var original_confirm_events: Array[InputEvent]
var original_cancel_events: Array[InputEvent]


class TestInputManager extends InputManager:
	var now_ms := 0

	func _now_ms() -> int:
		return now_ms


func before_each() -> void:
	original_confirm_events = InputMap.action_get_events(&"confirm")
	original_cancel_events = InputMap.action_get_events(&"cancel")
	manager = TestInputManager.new()


func after_each() -> void:
	manager.free()
	_restore_action(&"confirm", original_confirm_events)
	_restore_action(&"cancel", original_cancel_events)


func test_key_press_switches_to_keyboard_mouse() -> void:
	var event := InputEventKey.new()
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)


func test_mouse_button_switches_to_keyboard_mouse() -> void:
	manager._input(_pressed_key())
	var event := InputEventMouseButton.new()
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)


func test_mouse_motion_above_three_pixels_is_meaningful() -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(3.01, 0.0)
	assert_true(manager.is_meaningful_event(event))


func test_mouse_motion_at_or_below_three_pixels_is_ignored() -> void:
	for distance in [0.0, 3.0]:
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(distance, 0.0)
		assert_false(manager.is_meaningful_event(event))


func test_joy_button_switches_to_controller() -> void:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)


func test_joy_axis_below_quarter_is_ignored() -> void:
	var event := InputEventJoypadMotion.new()
	event.axis_value = 0.249
	assert_false(manager.is_meaningful_event(event))


func test_joy_axis_at_quarter_is_controller_input() -> void:
	var event := InputEventJoypadMotion.new()
	event.axis_value = -0.25
	manager._input(event)
	assert_true(manager.is_meaningful_event(event))
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)


func test_navigation_key_selects_snapped_without_changing_input_family() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)


func test_controller_button_and_axis_select_snapped() -> void:
	manager._input(_joy_button(JOY_BUTTON_A))
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)
	manager._set_cursor_behavior(manager.CursorBehavior.FREE)
	var axis := InputEventJoypadMotion.new()
	axis.axis_value = 0.25
	manager._input(axis)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)


func test_ordinary_typing_preserves_cursor_behavior() -> void:
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	var event := InputEventKey.new()
	event.keycode = KEY_T
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)


func test_genuine_mouse_input_selects_free() -> void:
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(140, 80)
	motion.relative = Vector2(8, 0)
	manager._input(motion)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.FREE)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	var button := InputEventMouseButton.new()
	button.pressed = true
	manager._input(button)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.FREE)


func test_cursor_behavior_signal_emits_only_on_actual_changes() -> void:
	watch_signals(manager)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	manager._set_cursor_behavior(manager.CursorBehavior.FREE)
	manager._set_cursor_behavior(manager.CursorBehavior.FREE)
	assert_signal_emit_count(manager, "cursor_behavior_changed", 2)


func test_expected_warp_motion_within_tolerance_preserves_controller_and_snapped() -> void:
	manager.now_ms = 500
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	manager.expect_mouse_warp(Vector2(300, 200))
	var synthetic := InputEventMouseMotion.new()
	synthetic.position = Vector2(300.5, 199.5)
	synthetic.relative = Vector2(100, 50)
	manager._input(synthetic)
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)


func test_motion_outside_expected_warp_tolerance_is_genuine_mouse_input() -> void:
	manager.now_ms = 500
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	manager.expect_mouse_warp(Vector2(300, 200))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(303, 200)
	motion.relative = Vector2(8, 0)
	manager._input(motion)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.FREE)


func test_expired_warp_expectation_cannot_suppress_real_mouse_input() -> void:
	manager.now_ms = 500
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	manager.expect_mouse_warp(Vector2(300, 200))
	manager.now_ms += manager.WARP_SUPPRESSION_MS + 1
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(300, 200)
	motion.relative = Vector2(8, 0)
	manager._input(motion)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.FREE)


func test_connected_name_selection_uses_remaining_device_then_default() -> void:
	manager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	assert_eq(manager.get_active_controller_type(), InputIconMap.ControllerType.PLAYSTATION)
	manager.update_controller_from_connected_names([])
	assert_eq(manager.get_active_controller_type(), InputIconMap.ControllerType.STEAM_DECK)


func test_disconnect_rechecks_remaining_connected_device_names() -> void:
	manager.update_controller_from_connected_names(["Xbox Wireless Controller", "DualSense Wireless Controller"])
	manager.handle_joy_connection_changed(["DualSense Wireless Controller"])
	assert_eq(manager.get_active_controller_type(), InputIconMap.ControllerType.PLAYSTATION)


func test_connect_and_reconnect_update_controller_family() -> void:
	manager.handle_joy_connection_changed(["Xbox Wireless Controller"])
	assert_eq(manager.get_active_controller_type(), InputIconMap.ControllerType.XBOX)
	manager.handle_joy_connection_changed([])
	manager.handle_joy_connection_changed(["Nintendo Switch Pro Controller"])
	assert_eq(manager.get_active_controller_type(), InputIconMap.ControllerType.NINTENDO_SWITCH)


func test_mode_and_family_signals_emit_only_on_actual_changes() -> void:
	watch_signals(manager)
	manager._input(_joy_button(JOY_BUTTON_A))
	manager._input(_joy_button(JOY_BUTTON_A))
	manager._input(_pressed_key())
	manager._input(_pressed_key())
	manager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	manager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	assert_signal_emit_count(manager, "input_mode_changed", 2)
	assert_signal_emit_count(manager, "controller_type_changed", 1)


func test_controller_input_updates_family_and_mode() -> void:
	manager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	var event := InputEventJoypadButton.new()
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_active_controller_type(), InputIconMap.ControllerType.STEAM_DECK)


func test_required_semantic_actions_exist() -> void:
	for action in [
		&"nav_up", &"nav_down", &"nav_left", &"nav_right", &"confirm", &"cancel",
		&"page_previous", &"page_next", &"section_previous", &"section_next",
		&"action_1", &"action_2", &"action_3", &"action_4", &"shift_action",
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_up", &"camera_pan_down",
		&"zoom_in", &"zoom_out", &"recenter", &"refund_progression",
	]:
		assert_true(InputMap.has_action(action), str(action))


func test_navigation_actions_include_dpad_buttons() -> void:
	var expected := {&"nav_up": 11, &"nav_down": 12, &"nav_left": 13, &"nav_right": 14}
	for action in expected:
		assert_true(_has_joy_button(action, expected[action]), str(action))


func test_zoom_actions_use_trigger_axes() -> void:
	assert_true(_has_joy_axis(&"zoom_in", 5, 1.0))
	assert_true(_has_joy_axis(&"zoom_out", 4, 1.0))


func test_controller_family_rebinds_physical_confirm_and_cancel_positions() -> void:
	var cases := [
		["Nintendo Switch Pro Controller", InputIconMap.ControllerType.NINTENDO_SWITCH],
		["Nintendo Switch 2 Pro Controller", InputIconMap.ControllerType.NINTENDO_SWITCH_2],
		["Xbox Wireless Controller", InputIconMap.ControllerType.XBOX],
		["DualSense Wireless Controller", InputIconMap.ControllerType.PLAYSTATION],
		["Steam Deck", InputIconMap.ControllerType.STEAM_DECK],
	]
	for item in cases:
		manager.update_controller_from_connected_names([item[0]])
		assert_eq(manager.get_active_controller_type(), item[1])
		var expected_confirm := JOY_BUTTON_B if item[1] in [InputIconMap.ControllerType.NINTENDO_SWITCH, InputIconMap.ControllerType.NINTENDO_SWITCH_2] else JOY_BUTTON_A
		var expected_cancel := JOY_BUTTON_A if item[1] in [InputIconMap.ControllerType.NINTENDO_SWITCH, InputIconMap.ControllerType.NINTENDO_SWITCH_2] else JOY_BUTTON_B
		assert_eq(_joy_buttons(&"confirm"), [expected_confirm], str(item[0]))
		assert_eq(_joy_buttons(&"cancel"), [expected_cancel], str(item[0]))
		assert_true(InputMap.event_is_action(_joy_button(expected_confirm), &"confirm"))
		assert_true(InputMap.event_is_action(_joy_button(expected_cancel), &"cancel"))


func test_repeated_family_switches_keep_one_joy_binding_and_preserve_action_slots() -> void:
	var original_action_buttons := [_joy_buttons(&"action_1"), _joy_buttons(&"action_2"), _joy_buttons(&"action_3"), _joy_buttons(&"action_4")]
	for device_name in ["Nintendo Switch Pro Controller", "Xbox Wireless Controller", "Nintendo Switch Pro Controller", "Nintendo Switch Pro Controller"]:
		manager.update_controller_from_connected_names([device_name])
	assert_eq(_joy_buttons(&"confirm"), [JOY_BUTTON_B])
	assert_eq(_joy_buttons(&"cancel"), [JOY_BUTTON_A])
	for index in 4:
		assert_eq(_joy_buttons(StringName("action_%d" % (index + 1))), original_action_buttons[index])


func test_unknown_connected_name_uses_steam_fallback_bindings() -> void:
	manager.update_controller_from_connected_names(["mystery pad"])
	assert_eq(manager.get_active_controller_type(), InputIconMap.ControllerType.STEAM_DECK)
	assert_eq(_joy_buttons(&"confirm"), [JOY_BUTTON_A])
	assert_eq(_joy_buttons(&"cancel"), [JOY_BUTTON_B])


func _pressed_key() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	return event


func _has_joy_button(action: StringName, button_index: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button_index:
			return true
	return false


func _has_joy_axis(action: StringName, axis: int, value: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, value):
			return true
	return false


func _joy_buttons(action: StringName) -> Array[int]:
	var buttons: Array[int] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			buttons.append(event.button_index)
	return buttons


func _restore_action(action: StringName, events: Array[InputEvent]) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


func _joy_button(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index as JoyButton
	event.pressed = true
	return event
