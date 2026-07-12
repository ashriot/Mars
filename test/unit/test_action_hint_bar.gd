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


func test_keyboard_mouse_mode_hides_non_clickable_hint_bar() -> void:
	var bar = HintBarScene.instantiate()
	add_child_autofree(bar)
	var hints: Array[Dictionary] = [{action = &"cancel", label = "Back", enabled = true}]
	bar.set_hints(hints)
	bar.refresh(InputManager.InputMode.KEYBOARD_MOUSE, InputIconMap.ControllerType.XBOX)
	assert_false(bar.visible)
	assert_eq(bar.get_hint_count(), 1, "hints remain available when controller mode resumes")
	bar.refresh(InputManager.InputMode.CONTROLLER, InputIconMap.ControllerType.XBOX)
	assert_true(bar.visible)


func test_missing_glyph_keeps_text_and_disabled_state() -> void:
	var bar = HintBarScene.instantiate()
	add_child_autofree(bar)
	var hints: Array[Dictionary] = [{action = &"unmapped", label = "Mystery", enabled = false}]
	bar.set_hints(hints)
	bar.refresh(InputManager.InputMode.CONTROLLER, InputIconMap.ControllerType.XBOX)
	assert_true(bar.get_hint(0).visible)
	assert_false(bar.get_hint(0).glyph.visible)
	assert_false(bar.get_hint(0).enabled)


func test_replacing_hints_removes_old_nodes_synchronously() -> void:
	var bar = HintBarScene.instantiate()
	add_child_autofree(bar)
	var first: Array[Dictionary] = [
		{action = &"confirm", label = "Accept", enabled = true},
		{action = &"cancel", label = "Back", enabled = true},
	]
	bar.set_hints(first)
	var second: Array[Dictionary] = [{action = &"action_1", label = "Use", enabled = true}]
	bar.set_hints(second)
	assert_eq(bar.get_child_count(), 1)
	assert_eq(bar.get_hint_count(), 1)
	assert_eq(bar.get_hint(0).label.text, "Use")
