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


func test_disconnect_falls_back_to_remaining_injected_device_name() -> void:
	manager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	assert_eq(manager.get_active_controller_type(), InputIconMap.ControllerType.PLAYSTATION)
	manager.update_controller_from_connected_names([])
	assert_eq(manager.get_active_controller_type(), InputIconMap.ControllerType.STEAM_DECK)


func _pressed_key() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	return event
