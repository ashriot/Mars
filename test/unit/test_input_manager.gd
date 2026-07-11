extends GutTest

const InputManagerScript := preload("res://src/singletons/input_manager.gd")

var manager: Node


func before_each() -> void:
	manager = InputManagerScript.new()


func after_each() -> void:
	manager.free()


func test_key_press_switches_to_keyboard() -> void:
	var event := InputEventKey.new()
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD)


func test_mouse_button_switches_to_mouse() -> void:
	manager._input(_pressed_key())
	var event := InputEventMouseButton.new()
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.MOUSE)


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
	manager._input(_pressed_key())
	manager._input(_pressed_key())
	manager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	manager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	assert_signal_emit_count(manager, "input_mode_changed", 1)
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
