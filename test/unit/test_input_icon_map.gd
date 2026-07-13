extends GutTest


func test_controller_detection_and_fallback() -> void:
	assert_eq(InputIconMap.get_controller_type_from_name("DualSense Wireless Controller"), InputIconMap.ControllerType.PLAYSTATION)
	assert_eq(InputIconMap.get_controller_type_from_name("Nintendo Switch Pro Controller"), InputIconMap.ControllerType.NINTENDO_SWITCH)
	assert_eq(InputIconMap.get_controller_type_from_name("Steam Deck"), InputIconMap.ControllerType.STEAM_DECK)
	assert_eq(InputIconMap.get_controller_type_from_name("mystery pad"), InputIconMap.ControllerType.STEAM_DECK)


func test_each_controller_family_resolves_confirm_cancel_and_actions() -> void:
	for family in InputIconMap.runtime_controller_types():
		if family == InputIconMap.ControllerType.KEYBOARD_MOUSE:
			continue
		for action in [&"confirm", &"cancel", &"action_1", &"action_2", &"action_3", &"action_4", &"shift_left", &"shift_right"]:
			var path := InputIconMap.get_glyph_path(family, action)
			assert_ne(path, "", "%s %s" % [family, action])
			assert_true(ResourceLoader.exists(path), path)
	for action in [&"confirm", &"cancel"]:
		var path := InputIconMap.get_glyph_path(InputIconMap.ControllerType.KEYBOARD_MOUSE, action)
		assert_ne(path, "", "keyboard %s" % action)
		assert_true(ResourceLoader.exists(path), path)


func test_keyboard_battle_actions_resolve_kenney_textures() -> void:
	var expected := {
		&"action_1": "keyboard_1.svg",
		&"action_2": "keyboard_2.svg",
		&"action_3": "keyboard_3.svg",
		&"action_4": "keyboard_4.svg",
		&"shift_left": "keyboard_q.svg",
		&"shift_right": "keyboard_e.svg",
	}
	for action: StringName in expected:
		var path := InputIconMap.get_glyph_path(InputIconMap.ControllerType.KEYBOARD_MOUSE, action)
		assert_true(path.ends_with(expected[action]), str(action))
		assert_true(ResourceLoader.exists(path), path)


func test_nintendo_uses_platform_confirm_cancel_positions() -> void:
	for family in [InputIconMap.ControllerType.NINTENDO_SWITCH, InputIconMap.ControllerType.NINTENDO_SWITCH_2]:
		assert_true(InputIconMap.get_glyph_path(family, &"confirm").ends_with("switch_button_a.svg"))
		assert_true(InputIconMap.get_glyph_path(family, &"cancel").ends_with("switch_button_b.svg"))


func test_invalid_family_falls_back_to_steam_deck() -> void:
	assert_eq(
		InputIconMap.get_glyph_path(99 as InputIconMap.ControllerType, &"confirm"),
		InputIconMap.get_glyph_path(InputIconMap.ControllerType.STEAM_DECK, &"confirm")
	)


func test_missing_action_returns_empty_path() -> void:
	assert_eq(InputIconMap.get_glyph_path(InputIconMap.ControllerType.XBOX, &"not_real"), "")
