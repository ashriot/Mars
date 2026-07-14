extends GutTest

const InputManagerScript := preload("res://src/singletons/input_manager.gd")
const SYNTHETIC_UNCONNECTED_JOY_DEVICE := 127

var manager: Node
var original_confirm_events: Array[InputEvent]
var original_cancel_events: Array[InputEvent]
var original_terminal_security_events: Array[InputEvent]


class TestInputManager extends InputManager:
	var now_ms := 0

	func _now_ms() -> int:
		return now_ms


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


func test_mouse_button_switches_to_keyboard_mouse() -> void:
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	var event := InputEventMouseButton.new()
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.FREE)


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


func test_arrow_and_wasd_navigation_select_snapped_keyboard_mouse() -> void:
	var cases: Array[InputEventKey] = [
		_key(KEY_LEFT),
		_key(KEY_RIGHT),
		_key(KEY_UP),
		_key(KEY_DOWN),
		_physical_key(KEY_A),
		_physical_key(KEY_D),
		_physical_key(KEY_W),
		_physical_key(KEY_S),
	]
	for event: InputEventKey in cases:
		manager._set_cursor_behavior(manager.CursorBehavior.FREE)
		manager._input(event)
		assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
		assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)


func test_keyboard_action_hotkeys_select_snapped_keyboard_mouse() -> void:
	for keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		manager._set_cursor_behavior(manager.CursorBehavior.FREE)
		manager._input(_physical_key(keycode))
		assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
		assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)


func test_terminal_extraction_keyboard_shortcut_selects_snapped_keyboard_mode() -> void:
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.FREE)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_5
	event.pressed = true
	manager._input(event)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)


func test_controller_button_and_axis_select_snapped() -> void:
	manager._input(_unconnected_joy_button(JOY_BUTTON_A))
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


func test_mouse_motion_does_not_take_ownership_from_controller() -> void:
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(140, 80)
	motion.relative = Vector2(8, 0)
	manager._input(motion)
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)


func test_pressed_mouse_button_takes_ownership_and_selects_free() -> void:
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	var button := InputEventMouseButton.new()
	button.pressed = true
	manager._input(button)
	assert_eq(manager.get_active_mode(), manager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.FREE)


func test_restore_active_mode_reapplies_a_transition_snapshot() -> void:
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	var mode_before_transition: int = manager.get_active_mode()
	manager._set_active_mode(manager.InputMode.KEYBOARD_MOUSE)

	manager.restore_active_mode(mode_before_transition)

	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)


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
	assert_eq(manager._expected_warp_position, Vector2(300, 200))
	var duplicate := synthetic.duplicate() as InputEventMouseMotion
	duplicate.position = Vector2(299.5, 200.5)
	manager._input(duplicate)
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)
	assert_eq(manager._expected_warp_deadline_ms, 500 + manager.WARP_SUPPRESSION_MS, "duplicates do not extend the deadline")
	var genuine := synthetic.duplicate() as InputEventMouseMotion
	genuine.position = Vector2(310, 200)
	manager._input(genuine)
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)
	assert_eq(manager._expected_warp_position, Vector2.INF)
	assert_eq(manager._expected_warp_deadline_ms, 0)


func test_expected_warp_exact_deadline_is_suppressed_and_expiry_clears_payload() -> void:
	manager.now_ms = 500
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	manager.expect_mouse_warp(Vector2(300, 200))
	manager.now_ms = 500 + manager.WARP_SUPPRESSION_MS
	var boundary := InputEventMouseMotion.new()
	boundary.position = Vector2(300, 200)
	boundary.relative = Vector2(8, 0)
	manager._input(boundary)
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager._expected_warp_position, Vector2(300, 200))
	manager.now_ms += 1
	manager._input(boundary)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)
	assert_eq(manager._expected_warp_position, Vector2.INF)
	assert_eq(manager._expected_warp_deadline_ms, 0)


func test_motion_outside_expected_warp_tolerance_still_preserves_controller_mode() -> void:
	manager.now_ms = 500
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	manager.expect_mouse_warp(Vector2(300, 200))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(303, 200)
	motion.relative = Vector2(8, 0)
	manager._input(motion)
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)
	assert_eq(manager._expected_warp_position, Vector2.INF)
	assert_eq(manager._expected_warp_deadline_ms, 0)


func test_expired_warp_expectation_does_not_turn_motion_into_mouse_takeover() -> void:
	manager.now_ms = 500
	manager._set_active_mode(manager.InputMode.CONTROLLER)
	manager._set_cursor_behavior(manager.CursorBehavior.SNAPPED)
	manager.expect_mouse_warp(Vector2(300, 200))
	manager.now_ms += manager.WARP_SUPPRESSION_MS + 1
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(300, 200)
	motion.relative = Vector2(8, 0)
	manager._input(motion)
	assert_eq(manager.get_active_mode(), manager.InputMode.CONTROLLER)
	assert_eq(manager.get_cursor_behavior(), manager.CursorBehavior.SNAPPED)


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
		&"page_previous", &"page_next", &"section_previous", &"section_next",
		&"action_1", &"action_2", &"action_3", &"action_4", &"shift_left", &"shift_right",
		&"terminal_security", &"terminal_scan", &"terminal_medical", &"terminal_finance", &"terminal_extract",
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_up", &"camera_pan_down",
		&"zoom_in", &"zoom_out", &"recenter", &"refund_progression",
	]:
		assert_true(InputMap.has_action(action), str(action))


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
