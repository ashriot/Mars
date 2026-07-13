extends GutTest


func test_missing_action_hides_without_error() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"not_real")
	glyph.refresh(false, InputIconMap.ControllerType.XBOX)
	assert_false(glyph.visible)
	assert_null(glyph.texture_normal)
	assert_null(glyph.texture_pressed)
	assert_null(glyph.texture_disabled)
	glyph.refresh(true, InputIconMap.ControllerType.XBOX)
	assert_false(glyph.visible)
	assert_null(glyph.texture_normal)
	assert_null(glyph.texture_pressed)
	assert_null(glyph.texture_disabled)


func test_known_action_shows_controller_texture() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"confirm")
	glyph.refresh(true, InputIconMap.ControllerType.PLAYSTATION)
	assert_true(glyph.visible)
	assert_not_null(glyph.texture_normal)


func test_keyboard_mouse_mode_shows_keyboard_texture() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"action_2")
	glyph.refresh(false, InputIconMap.ControllerType.XBOX)
	assert_true(glyph.visible)
	assert_eq(glyph.texture_normal.resource_path.get_file(), "keyboard_2.svg")
	assert_null(glyph.get_node_or_null("KeyboardLabel"))


func test_controller_mode_shows_controller_texture() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"action_2")
	glyph.refresh(true, InputIconMap.ControllerType.XBOX)
	assert_eq(glyph.texture_normal.resource_path.get_file(), "xbox_button_b.svg")
	assert_null(glyph.get_node_or_null("KeyboardLabel"))


func test_directional_shift_keyboard_mode_uses_kenney_textures() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"shift_left")
	assert_true(glyph.texture_normal.resource_path.ends_with("keyboard_q.svg"))
	glyph.set_action(&"shift_right")
	assert_true(glyph.texture_normal.resource_path.ends_with("keyboard_e.svg"))


func test_set_action_refreshes_immediately_inside_tree() -> void:
	InputManager._input(_pressed_joy_button())
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"confirm")
	assert_true(glyph.visible)
	glyph.set_action(&"not_real")
	assert_false(glyph.visible)


func test_input_manager_mode_signal_refreshes_glyph() -> void:
	InputManager._input(_pressed_joy_button())
	var glyph := DynamicGlyph.new()
	glyph.action = &"action_1"
	add_child_autofree(glyph)
	assert_true(glyph.visible)
	var controller_texture := glyph.texture_normal
	assert_not_null(controller_texture)
	var key := InputEventKey.new()
	key.pressed = true
	InputManager._input(key)
	assert_true(glyph.visible)
	assert_eq(glyph.texture_normal.resource_path.get_file(), "keyboard_1.svg")
	InputManager._input(_pressed_joy_button())
	assert_true(glyph.visible)
	assert_same(glyph.texture_normal, controller_texture)


func test_input_manager_family_signal_refreshes_glyph_texture() -> void:
	InputManager._input(_pressed_joy_button())
	var glyph := DynamicGlyph.new()
	glyph.action = &"confirm"
	add_child_autofree(glyph)
	var old_texture := glyph.texture_normal
	InputManager.update_controller_from_connected_names(["DualSense Wireless Controller"])
	assert_ne(glyph.texture_normal, old_texture)


func _pressed_joy_button() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	return event
