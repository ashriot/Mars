extends GutTest

const InputManagerScript := preload("res://src/singletons/input_manager.gd")
const SYNTHETIC_UNCONNECTED_JOY_DEVICE := 127

var manager: Node
var original_confirm_events: Array[InputEvent]
var original_cancel_events: Array[InputEvent]
var original_terminal_security_events: Array[InputEvent]


class TestInputManager extends InputManager:
	var mouse_modes: Array[Input.MouseMode] = []
	var handled_event_count := 0
	var custom_cursor_hotspot := Vector2.INF
	var connected_device_names: Array[String] = []

	func _set_mouse_mode(mode: Input.MouseMode) -> void:
		mouse_modes.append(mode)

	func _install_hardware_cursor(_texture: Texture2D, hotspot: Vector2) -> void:
		custom_cursor_hotspot = hotspot

	func _mark_input_handled() -> void:
		handled_event_count += 1

	func _connected_device_names() -> Array[String]:
		return connected_device_names


func before_each() -> void:
	original_confirm_events = InputMap.action_get_events(&"confirm")
	original_cancel_events = InputMap.action_get_events(&"cancel")
	original_terminal_security_events = InputMap.action_get_events(&"terminal_security")
	manager = TestInputManager.new()


func after_each() -> void:
	manager.free()
	_restore_action(&"confirm", original_confirm_events)
	_restore_action(&"cancel", original_cancel_events)
	_restore_action(&"terminal_security", original_terminal_security_events)


func test_key_press_switches_to_keyboard_mouse() -> void:
	var event := InputEventKey.new()
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)


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


func test_controller_hides_pointer_and_selects_focus_presentation() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.FOCUS)
	assert_eq(manager.mouse_modes.back(), Input.MOUSE_MODE_HIDDEN)


func test_mouse_motion_cannot_leave_controller_mode() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_mouse_motion(Vector2(12, 0)))
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.FOCUS)


func test_one_pixel_mouse_motion_selects_pointer_only_in_keyboard_mouse_mode() -> void:
	manager._set_presentation_mode(manager.PresentationMode.FOCUS)
	manager._input(_mouse_motion(Vector2(1, 0)))
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.POINTER)


func test_controller_mouse_handoff_consumes_press_and_matching_release() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_mouse_button(MOUSE_BUTTON_LEFT, true))
	manager._input(_mouse_button(MOUSE_BUTTON_LEFT, false))
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.POINTER)
	assert_eq(manager.handled_event_count, 2)
	assert_eq(manager._consumed_mouse_button, MOUSE_BUTTON_NONE)


func test_touch_press_leaves_controller_mode_and_selects_pointer_presentation() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	manager._input(touch)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.POINTER)


func test_consumed_mouse_transaction_survives_interleaved_controller_and_keyboard_input() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_mouse_button(MOUSE_BUTTON_LEFT, true))
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_key(KEY_UP))
	assert_eq(manager.handled_event_count, 1)
	assert_eq(manager._consumed_mouse_button, MOUSE_BUTTON_LEFT)

	manager._input(_mouse_button(MOUSE_BUTTON_LEFT, false))

	assert_eq(manager.handled_event_count, 2)
	assert_eq(manager._consumed_mouse_button, MOUSE_BUTTON_NONE)


func test_wheel_handoff_does_not_leave_a_pending_mouse_transaction() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_mouse_button(MOUSE_BUTTON_WHEEL_UP, true))
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.POINTER)
	assert_eq(manager.handled_event_count, 1)
	assert_eq(manager._consumed_mouse_button, MOUSE_BUTTON_NONE)

	manager._input(_mouse_button(MOUSE_BUTTON_LEFT, true))
	manager._input(_mouse_button(MOUSE_BUTTON_LEFT, false))

	assert_eq(manager.handled_event_count, 1, "subsequent pointer-owned clicks proceed normally")
	assert_eq(manager._consumed_mouse_button, MOUSE_BUTTON_NONE)


func test_pending_handoff_consumes_only_the_initiating_button_transaction() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_mouse_button(MOUSE_BUTTON_LEFT, true))
	manager._input(_mouse_button(MOUSE_BUTTON_RIGHT, true))
	manager._input(_mouse_button(MOUSE_BUTTON_RIGHT, false))
	assert_eq(manager.handled_event_count, 1, "a different button remains available to pointer ownership")
	assert_eq(manager._consumed_mouse_button, MOUSE_BUTTON_LEFT)

	manager._input(_mouse_button(MOUSE_BUTTON_LEFT, false))
	assert_eq(manager.handled_event_count, 2)
	assert_eq(manager._consumed_mouse_button, MOUSE_BUTTON_NONE)

	manager._input(_mouse_button(MOUSE_BUTTON_RIGHT, true))
	manager._input(_mouse_button(MOUSE_BUTTON_RIGHT, false))
	assert_eq(manager.handled_event_count, 2, "later clicks proceed normally after the handoff release")


func test_keyboard_from_controller_reveals_pointer_and_does_not_consume_action() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_key(KEY_UP))
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.FOCUS)
	assert_eq(manager.mouse_modes.back(), Input.MOUSE_MODE_VISIBLE)
	assert_eq(manager.handled_event_count, 0)


func test_first_direction_after_pointer_restores_focus_and_is_consumed() -> void:
	manager._set_presentation_mode(manager.PresentationMode.POINTER)
	manager._input(_key(KEY_DOWN))
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.FOCUS)
	assert_eq(manager.handled_event_count, 1)
	manager._input(_key(KEY_DOWN))
	assert_eq(manager.handled_event_count, 1)


func test_non_navigation_key_from_pointer_is_not_consumed() -> void:
	manager._set_presentation_mode(manager.PresentationMode.POINTER)
	manager._input(_physical_key(KEY_1))
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.POINTER)
	assert_eq(manager.handled_event_count, 0)


func test_ready_installs_styled_hardware_cursor_at_arrow_tip() -> void:
	manager._ready()
	assert_eq(manager.custom_cursor_hotspot, Vector2(2, 2))
	assert_eq(manager.mouse_modes.back(), Input.MOUSE_MODE_VISIBLE)


func test_restore_active_mode_reapplies_a_transition_snapshot() -> void:
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	var mode_before_transition: int = manager.get_active_mode()
	manager._set_active_mode(manager.InputMode.KEYBOARD_MOUSE)

	manager.restore_active_mode(mode_before_transition)

	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)


func test_presentation_mode_signal_emits_only_on_actual_changes() -> void:
	watch_signals(manager)
	manager._set_presentation_mode(manager.PresentationMode.FOCUS)
	manager._set_presentation_mode(manager.PresentationMode.FOCUS)
	manager._set_presentation_mode(manager.PresentationMode.POINTER)
	manager._set_presentation_mode(manager.PresentationMode.POINTER)
	assert_signal_emit_count(manager, "presentation_mode_changed", 2)


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


func test_controller_connection_claims_input_ownership() -> void:
	manager.handle_joy_connection_changed(["Xbox Wireless Controller"])

	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.FOCUS)
	assert_true(not manager.mouse_modes.is_empty() and manager.mouse_modes.back() == Input.MOUSE_MODE_HIDDEN)


func test_ready_with_connected_controller_claims_input_ownership() -> void:
	var connected_names: Array[String] = ["DualSense Wireless Controller"]
	manager.connected_device_names = connected_names

	manager._ready()

	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_presentation_mode(), manager.PresentationMode.FOCUS)
	assert_true(not manager.mouse_modes.is_empty() and manager.mouse_modes.back() == Input.MOUSE_MODE_HIDDEN)


func test_mode_and_family_signals_emit_only_on_actual_changes() -> void:
	watch_signals(manager)
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
	manager._input(_pressed_key())
	manager._input(_pressed_key())
	manager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	manager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	assert_signal_emit_count(manager, "input_mode_changed", 2)
	assert_signal_emit_count(manager, "controller_type_changed", 1)


func test_controller_input_updates_family_and_mode() -> void:
	manager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	var event := _unconnected_joy_button(JOY_BUTTON_A)
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_active_controller_type(), InputIconMap.ControllerType.STEAM_DECK)


func _joy_button_for(action: StringName) -> JoyButton:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return event.button_index
	return JOY_BUTTON_INVALID


func test_terminal_actions_use_numbers_shoulders_and_non_cancel_face_buttons() -> void:
	var expected := {
		&"terminal_security": [KEY_1, JOY_BUTTON_A],
		&"terminal_medical": [KEY_2, JOY_BUTTON_X],
		&"terminal_finance": [KEY_3, JOY_BUTTON_Y],
		&"terminal_scan": [KEY_4, JOY_BUTTON_LEFT_SHOULDER],
		&"terminal_extract": [KEY_5, JOY_BUTTON_RIGHT_SHOULDER],
	}
	for action: StringName in expected:
		var events := InputMap.action_get_events(action)
		assert_eq(events.filter(func(event): return event is InputEventKey and event.physical_keycode == expected[action][0]).size(), 1, str(action))
		assert_eq(events.filter(func(event): return event is InputEventJoypadButton and event.button_index == expected[action][1]).size(), 1, str(action))


func test_nintendo_rebinds_terminal_security_to_a_and_keeps_b_as_cancel() -> void:
	manager._set_active_controller_type(InputIconMap.ControllerType.NINTENDO_SWITCH)
	assert_eq(_joy_button_for(&"terminal_security"), JOY_BUTTON_B)
	assert_eq(_joy_button_for(&"cancel"), JOY_BUTTON_A)


func test_required_semantic_actions_exist() -> void:
	for action in [
		&"nav_up", &"nav_down", &"nav_left", &"nav_right", &"confirm", &"cancel",
		&"hub_tab_previous", &"hub_tab_next", &"hub_role_previous", &"hub_role_next",
		&"action_1", &"action_2", &"action_3", &"action_4", &"shift_left", &"shift_right",
		&"terminal_security", &"terminal_scan", &"terminal_medical", &"terminal_finance", &"terminal_extract",
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_up", &"camera_pan_down",
		&"zoom_in", &"zoom_out", &"recenter", &"refund_progression",
	]:
		assert_true(InputMap.has_action(action), str(action))


func test_hub_shoulder_actions_are_controller_only() -> void:
	var expected := {
		&"hub_tab_previous": [JOY_AXIS_TRIGGER_LEFT, -1],
		&"hub_tab_next": [JOY_AXIS_TRIGGER_RIGHT, -1],
		&"hub_role_previous": [-1, JOY_BUTTON_LEFT_SHOULDER],
		&"hub_role_next": [-1, JOY_BUTTON_RIGHT_SHOULDER],
	}
	for action: StringName in expected:
		assert_true(InputMap.has_action(action), str(action))
		assert_eq(InputMap.action_get_events(action).filter(func(event): return event is InputEventKey).size(), 0, "%s has no keyboard shortcut" % action)
		if expected[action][0] >= 0:
			assert_true(_has_joy_axis(action, expected[action][0], 1.0), str(action))
		else:
			assert_true(_has_joy_button(action, expected[action][1]), str(action))
	assert_false(InputMap.has_action(&"page_previous"))
	assert_false(InputMap.has_action(&"page_next"))
	assert_false(InputMap.has_action(&"section_previous"))
	assert_false(InputMap.has_action(&"section_next"))


func test_combat_shift_actions_use_directional_keys_and_triggers() -> void:
	assert_true(_has_physical_key(&"shift_left", KEY_Q))
	assert_true(_has_joy_axis(&"shift_left", JOY_AXIS_TRIGGER_LEFT, 1.0))
	assert_true(_has_physical_key(&"shift_right", KEY_E))
	assert_true(_has_joy_axis(&"shift_right", JOY_AXIS_TRIGGER_RIGHT, 1.0))


func test_legacy_combat_shift_action_is_removed() -> void:
	assert_false(InputMap.has_action(&"shift_action"))


func test_standard_ui_directions_include_arrows_wasd_and_controller_defaults() -> void:
	var expected := {
		&"ui_left": [KEY_LEFT, KEY_A, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0],
		&"ui_right": [KEY_RIGHT, KEY_D, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0],
		&"ui_up": [KEY_UP, KEY_W, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0],
		&"ui_down": [KEY_DOWN, KEY_S, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0],
	}
	for action: StringName in expected:
		var values: Array = expected[action]
		assert_true(_has_logical_key(action, values[0]), "%s arrow" % action)
		assert_true(_has_physical_key(action, values[1]), "%s WASD" % action)
		assert_true(_has_joy_button(action, values[2]), "%s D-pad" % action)
		assert_true(_has_joy_axis(action, values[3], values[4]), "%s stick" % action)


func test_custom_navigation_keeps_arrows_out_and_wasd_in() -> void:
	var expected := {
		&"nav_left": [KEY_LEFT, KEY_A],
		&"nav_right": [KEY_RIGHT, KEY_D],
		&"nav_up": [KEY_UP, KEY_W],
		&"nav_down": [KEY_DOWN, KEY_S],
	}
	for action: StringName in expected:
		assert_false(_has_logical_key(action, expected[action][0]), "%s excludes arrow" % action)
		assert_true(_has_physical_key(action, expected[action][1]), "%s keeps WASD" % action)


func test_dungeon_camera_uses_matching_arrow_keys_without_nav_overlap() -> void:
	var expected := {
		&"camera_pan_left": KEY_LEFT,
		&"camera_pan_right": KEY_RIGHT,
		&"camera_pan_up": KEY_UP,
		&"camera_pan_down": KEY_DOWN,
	}
	for action: StringName in expected:
		assert_true(_has_physical_key(action, expected[action]), str(action))
		var arrow := _physical_key(expected[action])
		for nav_action: StringName in [&"nav_left", &"nav_right", &"nav_up", &"nav_down"]:
			assert_false(arrow.is_action(nav_action), "%s does not trigger %s" % [action, nav_action])


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


func _has_logical_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.keycode == keycode:
			return true
	return false


func _has_physical_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _physical_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _mouse_motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event


func _mouse_button(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
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


func _unconnected_joy_button(index: int) -> InputEventJoypadButton:
	var event := _joy_button(index)
	event.device = SYNTHETIC_UNCONNECTED_JOY_DEVICE
	return event
