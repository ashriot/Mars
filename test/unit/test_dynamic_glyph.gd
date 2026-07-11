extends GutTest


func test_missing_action_hides_without_error() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"not_real")
	glyph.refresh(true, InputIconMap.ControllerType.XBOX)
	assert_false(glyph.visible)
	assert_null(glyph.texture_normal)


func test_known_action_shows_controller_texture() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"confirm")
	glyph.refresh(true, InputIconMap.ControllerType.PLAYSTATION)
	assert_true(glyph.visible)
	assert_not_null(glyph.texture_normal)


func test_non_controller_mode_hides_glyph() -> void:
	var glyph := DynamicGlyph.new()
	add_child_autofree(glyph)
	glyph.set_action(&"confirm")
	glyph.refresh(false, InputIconMap.ControllerType.XBOX)
	assert_false(glyph.visible)
