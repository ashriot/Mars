extends GutTest

const HintBarScene = preload("res://src/ui/navigation/action_hint_bar.tscn")


func test_controller_mode_shows_controller_glyphs() -> void:
	var bar = HintBarScene.instantiate()
	add_child_autofree(bar)
	var hints: Array[Dictionary] = [{action = &"confirm", label = "Accept", enabled = true}]
	bar.set_hints(hints)
	bar.refresh(InputManager.InputMode.CONTROLLER, InputIconMap.ControllerType.XBOX)
	assert_eq(bar.get_hint_count(), 1)
	assert_true(bar.get_hint(0).glyph.visible)
	assert_not_null(bar.get_hint(0).glyph.texture)


func test_keyboard_mode_shows_keyboard_prompt() -> void:
	var bar = HintBarScene.instantiate()
	add_child_autofree(bar)
	var hints: Array[Dictionary] = [{action = &"cancel", label = "Back", enabled = true}]
	bar.set_hints(hints)
	bar.refresh(InputManager.InputMode.KEYBOARD, InputIconMap.ControllerType.XBOX)
	assert_true(bar.get_hint(0).glyph.visible)
	assert_not_null(bar.get_hint(0).glyph.texture)


func test_mouse_mode_hides_glyph_but_keeps_action_label() -> void:
	var bar = HintBarScene.instantiate()
	add_child_autofree(bar)
	var hints: Array[Dictionary] = [{action = &"confirm", label = "Accept", enabled = true}]
	bar.set_hints(hints)
	bar.refresh(InputManager.InputMode.MOUSE, InputIconMap.ControllerType.XBOX)
	assert_false(bar.get_hint(0).glyph.visible)
	assert_true(bar.get_hint(0).visible)
	assert_eq(bar.get_hint(0).label.text, "Accept")


func test_missing_glyph_keeps_text_and_disabled_state() -> void:
	var bar = HintBarScene.instantiate()
	add_child_autofree(bar)
	var hints: Array[Dictionary] = [{action = &"unmapped", label = "Mystery", enabled = false}]
	bar.set_hints(hints)
	bar.refresh(InputManager.InputMode.CONTROLLER, InputIconMap.ControllerType.XBOX)
	assert_true(bar.get_hint(0).visible)
	assert_false(bar.get_hint(0).glyph.visible)
	assert_false(bar.get_hint(0).enabled)
