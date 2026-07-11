extends GutTest


func test_controller_detection_and_fallback() -> void:
	assert_eq(InputIconMap.get_controller_type_from_name("DualSense Wireless Controller"), InputIconMap.ControllerType.PLAYSTATION)
	assert_eq(InputIconMap.get_controller_type_from_name("Nintendo Switch Pro Controller"), InputIconMap.ControllerType.NINTENDO_SWITCH)
	assert_eq(InputIconMap.get_controller_type_from_name("Steam Deck"), InputIconMap.ControllerType.STEAM_DECK)
	assert_eq(InputIconMap.get_controller_type_from_name("mystery pad"), InputIconMap.ControllerType.STEAM_DECK)


func test_each_family_resolves_confirm_cancel_and_actions() -> void:
	for family in InputIconMap.runtime_controller_types():
		for action in [&"confirm", &"cancel", &"action_1", &"action_2", &"action_3", &"action_4"]:
			var path := InputIconMap.get_glyph_path(family, action)
			assert_ne(path, "", "%s %s" % [family, action])
			assert_true(ResourceLoader.exists(path), path)


func test_nintendo_uses_platform_confirm_cancel_positions() -> void:
	var family := InputIconMap.ControllerType.NINTENDO_SWITCH
	assert_true(InputIconMap.get_glyph_path(family, &"confirm").ends_with("switch_button_a.svg"))
	assert_true(InputIconMap.get_glyph_path(family, &"cancel").ends_with("switch_button_b.svg"))


func test_missing_action_returns_empty_path() -> void:
	assert_eq(InputIconMap.get_glyph_path(InputIconMap.ControllerType.XBOX, &"not_real"), "")
