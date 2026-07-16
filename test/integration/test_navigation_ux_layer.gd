extends GutTest

const UXScene = preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const HubScene = preload("res://src/hub/hub.tscn")

var saved_input_mode: InputManager.InputMode
var saved_presentation_mode: InputManager.PresentationMode
var saved_process_input: bool


class RecordingCursor extends NavigationCursor:
	var requested_modes: Array[Input.MouseMode] = []

	func _set_mouse_mode(mode: Input.MouseMode) -> void:
		requested_modes.append(mode)


class InputMotionRecorder extends Node:
	var motion_count := 0

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			motion_count += 1


func before_each() -> void:
	saved_input_mode = InputManager._active_mode
	saved_presentation_mode = InputManager._presentation_mode
	saved_process_input = InputManager.is_processing_input()


func after_each() -> void:
	InputManager._active_mode = saved_input_mode
	InputManager._presentation_mode = saved_presentation_mode
	InputManager.set_process_input(saved_process_input)


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _released_key(keycode: Key) -> InputEventKey:
	var event := _key(keycode)
	event.pressed = false
	return event


func _mouse_motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event


func _mouse_motion_at(position: Vector2, relative := Vector2.ZERO) -> InputEventMouseMotion:
	var event := _mouse_motion(relative)
	event.position = position
	event.global_position = position
	return event


func _mouse_button_at(position: Vector2, button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.global_position = position
	event.pressed = pressed
	return event


func _joy_direction(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _three_button_screen() -> Dictionary:
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var screen := VBoxContainer.new()
	screen.position = Vector2(100, 100)
	var top := Button.new()
	var middle := Button.new()
	var bottom := Button.new()
	for index in 3:
		var button: Button = [top, middle, bottom][index]
		button.text = ["TOP", "MIDDLE", "BOTTOM"][index]
		button.custom_minimum_size = Vector2(240, 40)
		button.focus_mode = Control.FOCUS_ALL
		screen.add_child(button)
	top.focus_neighbor_bottom = top.get_path_to(middle)
	middle.focus_neighbor_top = middle.get_path_to(top)
	middle.focus_neighbor_bottom = middle.get_path_to(bottom)
	bottom.focus_neighbor_top = bottom.get_path_to(middle)
	add_child_autofree(screen)
	ux.register_screen(screen, top)
	await get_tree().process_frame
	return {"ux": ux, "screen": screen, "top": top, "middle": middle, "bottom": bottom}


func _party_button_screen() -> Dictionary:
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var party := Control.new()
	party.name = "PartyMenu"
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(200, 48)
	party.add_child(button)
	add_child_autofree(party)
	ux.register_screen(party, button)
	await get_tree().process_frame
	return {"ux": ux, "party": party, "button": button}


func test_controller_focus_inside_party_menu_shows_hub_cursor_only() -> void:
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var party := Control.new()
	party.name = "PartyMenu"
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(200, 48)
	party.add_child(button)
	add_child_autofree(party)
	ux.register_screen(party, button)
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	button.grab_focus()
	await get_tree().process_frame
	assert_true(ux.cursor.is_tracking_hub_target())
	assert_same(ux.cursor._hub_target.get_ref(), button)


func test_pointer_handoff_hides_only_hub_cursor_and_preserves_focus_origin() -> void:
	var setup := await _party_button_screen()
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	setup.button.grab_focus()
	await get_tree().process_frame
	InputManager._input(_mouse_button_at(Vector2(500, 300), MOUSE_BUTTON_LEFT, true))
	assert_false(setup.ux.cursor.is_tracking_hub_target())
	assert_same(setup.ux.get_focus_target(), setup.button)
	InputManager._input(_mouse_button_at(Vector2(500, 300), MOUSE_BUTTON_LEFT, false))


func test_controller_to_keyboard_handoff_hides_hub_cursor_while_focus_stays_presented() -> void:
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	var setup := await _party_button_screen()
	assert_true(setup.ux.cursor.is_tracking_hub_target())

	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)

	assert_eq(InputManager.get_presentation_mode(), InputManager.PresentationMode.FOCUS)
	assert_same(setup.ux.get_focus_target(), setup.button)
	assert_false(setup.ux.cursor.is_tracking_hub_target())


func test_keyboard_to_controller_handoff_shows_hub_cursor_while_focus_stays_presented() -> void:
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	var setup := await _party_button_screen()
	assert_false(setup.ux.cursor.is_tracking_hub_target())

	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)

	assert_eq(InputManager.get_presentation_mode(), InputManager.PresentationMode.FOCUS)
	assert_same(setup.ux.get_focus_target(), setup.button)
	assert_true(setup.ux.cursor.is_tracking_hub_target())


func test_controller_focus_does_not_push_synthetic_mouse_motion() -> void:
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	var recorder := InputMotionRecorder.new()
	add_child_autofree(recorder)
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var party := Control.new()
	party.name = "PartyMenu"
	var button := Button.new()
	party.add_child(button)
	add_child_autofree(party)
	ux.register_screen(party, button)
	recorder.motion_count = 0

	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(recorder.motion_count, 0)


func test_mouse_motion_hides_focus_but_retains_navigation_origin() -> void:
	var setup := await _three_button_screen()
	var ux: NavigationUXLayer = setup.ux
	var top: Button = setup.top
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	top.grab_focus()
	await get_tree().process_frame
	assert_true(NavigationFocus._states.has(top.get_instance_id()))
	InputManager._input(_mouse_motion(Vector2(12, 0)))
	assert_same(ux.get_focus_target(), top)
	assert_same(get_viewport().gui_get_focus_owner(), top)
	assert_false(NavigationFocus._states.has(top.get_instance_id()))
	assert_false(ux.pointer_input_blocker.visible)


func test_first_keyboard_direction_after_pointer_only_restores_top_focus() -> void:
	var setup := await _three_button_screen()
	setup.top.grab_focus()
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.top)
	assert_true(NavigationFocus._states.has(setup.top.get_instance_id()))
	get_viewport().push_input(_released_key(KEY_DOWN))
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.middle)


func test_controller_direction_from_pointer_moves_immediately_and_hides_mouse() -> void:
	var setup := await _three_button_screen()
	var ux: NavigationUXLayer = setup.ux
	var original_cursor := ux.cursor
	original_cursor.set_process(false)
	ux.remove_child(original_cursor)
	original_cursor.free()
	var cursor := RecordingCursor.new()
	ux.add_child(cursor)
	ux.cursor = cursor
	cursor.set_process(false)
	cursor.hide()
	cursor.requested_modes.clear()
	setup.top.grab_focus()
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	var direction := _joy_direction(JOY_BUTTON_DPAD_DOWN, true)
	InputManager._input(direction)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
	assert_false(
		cursor.requested_modes.has(Input.MOUSE_MODE_VISIBLE),
		"unowned cursor processing cannot reveal the hardware cursor",
	)
	get_viewport().push_input(direction)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.middle)
	assert_true(ux.pointer_input_blocker.visible)
	assert_false(cursor.visible, "ordinary controller focus does not show the navigation cursor")


func test_pointer_hover_preserves_retained_origin_until_second_keyboard_direction() -> void:
	var setup := await _three_button_screen()
	var middle_position: Vector2 = setup.middle.get_global_rect().get_center()
	setup.top.grab_focus()
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	get_viewport().push_input(_mouse_motion_at(middle_position, Vector2(12, 0)), true)
	await get_tree().process_frame
	assert_true(setup.middle.is_hovered())
	assert_same(setup.ux.get_focus_target(), setup.top)
	assert_same(get_viewport().gui_get_focus_owner(), setup.top)

	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.top)
	assert_true(NavigationFocus._states.has(setup.top.get_instance_id()))

	get_viewport().push_input(_released_key(KEY_DOWN))
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.middle)


func test_pointer_blocker_suppresses_gui_hover_and_activation_only_in_focus() -> void:
	var setup := await _three_button_screen()
	var middle: Button = setup.middle
	var middle_position := middle.get_global_rect().get_center()
	var press_count := [0]
	middle.pressed.connect(func() -> void: press_count[0] += 1)
	InputManager.set_process_input(false)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)

	get_viewport().push_input(_mouse_motion_at(middle_position), true)
	get_viewport().push_input(_mouse_button_at(middle_position, MOUSE_BUTTON_LEFT, true), true)
	get_viewport().push_input(_mouse_button_at(middle_position, MOUSE_BUTTON_LEFT, false), true)
	await get_tree().process_frame
	assert_false(middle.is_hovered())
	assert_eq(press_count[0], 0)

	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	get_viewport().push_input(_mouse_motion_at(Vector2.ZERO), true)
	get_viewport().push_input(_mouse_motion_at(middle_position, middle_position), true)
	get_viewport().push_input(_mouse_button_at(middle_position, MOUSE_BUTTON_LEFT, true), true)
	get_viewport().push_input(_mouse_button_at(middle_position, MOUSE_BUTTON_LEFT, false), true)
	await get_tree().process_frame
	assert_true(middle.is_hovered())
	assert_eq(press_count[0], 1)


func test_controller_handoff_clears_existing_pointer_hover_without_mouse_motion() -> void:
	var setup := await _three_button_screen()
	var middle: Button = setup.middle
	var middle_position := middle.get_global_rect().get_center()
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	get_viewport().push_input(_mouse_motion_at(middle_position, Vector2(12, 0)), true)
	await get_tree().process_frame
	assert_true(middle.is_hovered())

	get_viewport().push_input(_joy_direction(JOY_BUTTON_A, true))
	await get_tree().process_frame
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
	assert_true(setup.ux.pointer_input_blocker.visible)
	assert_false(middle.is_hovered(), "controller focus clears stale pointer hover immediately")

	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	get_viewport().push_input(_mouse_motion_at(Vector2.ZERO), true)
	get_viewport().push_input(_mouse_motion_at(middle_position, middle_position), true)
	await get_tree().process_frame
	assert_true(middle.is_hovered(), "pointer mode restores the prior control's mouse behavior")


func test_keyboard_direction_from_controller_moves_immediately_and_reveals_mouse() -> void:
	var setup := await _three_button_screen()
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	setup.top.grab_focus()
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.middle)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.KEYBOARD_MOUSE)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	assert_false(setup.ux.cursor.visible, "keyboard focus does not show the navigation cursor")


func test_pointer_keyboard_controller_handoffs_preserve_one_logical_focus() -> void:
	var setup := await _three_button_screen()
	var ux: NavigationUXLayer = setup.ux
	var top: Button = setup.top
	var middle: Button = setup.middle
	var bottom: Button = setup.bottom
	var bottom_press_count := [0]
	bottom.pressed.connect(func() -> void: bottom_press_count[0] += 1)

	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), top)
	get_viewport().push_input(_released_key(KEY_DOWN))
	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), middle)
	get_viewport().push_input(_released_key(KEY_DOWN))

	get_viewport().push_input(_joy_direction(JOY_BUTTON_DPAD_DOWN, true))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), bottom)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
	assert_true(ux.pointer_input_blocker.visible)
	get_viewport().push_input(_joy_direction(JOY_BUTTON_DPAD_DOWN, false))

	get_viewport().push_input(_key(KEY_UP))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), middle)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.KEYBOARD_MOUSE)
	get_viewport().push_input(_released_key(KEY_UP))

	InputManager._input(_mouse_motion(Vector2(12, 0)))
	assert_same(ux.get_focus_target(), middle)
	assert_false(NavigationFocus._states.has(middle.get_instance_id()))

	InputManager._input(_joy_direction(JOY_BUTTON_A, true))
	var click_position := bottom.get_global_rect().get_center()
	get_viewport().push_input(_mouse_button_at(click_position, MOUSE_BUTTON_LEFT, true), true)
	get_viewport().push_input(_mouse_button_at(click_position, MOUSE_BUTTON_LEFT, false), true)
	await get_tree().process_frame
	assert_eq(bottom_press_count[0], 0)
	get_viewport().push_input(_mouse_button_at(click_position, MOUSE_BUTTON_LEFT, true), true)
	get_viewport().push_input(_mouse_button_at(click_position, MOUSE_BUTTON_LEFT, false), true)
	await get_tree().process_frame
	assert_eq(bottom_press_count[0], 1)


func test_focus_presentation_resolves_invalid_retained_target_to_fallback() -> void:
	var setup := await _three_button_screen()
	setup.top.grab_focus()
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	setup.top.disabled = true
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.middle)
	assert_same(setup.ux.get_focus_target(), setup.middle)
	assert_true(NavigationFocus._states.has(setup.middle.get_instance_id()))


func test_controller_direction_recovering_invalid_retained_focus_stops_at_fallback() -> void:
	var setup := await _three_button_screen()
	setup.top.grab_focus()
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	setup.top.disabled = true

	get_viewport().push_input(_joy_direction(JOY_BUTTON_DPAD_DOWN, true))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.middle)
	assert_same(setup.ux.get_focus_target(), setup.middle)
	get_viewport().push_input(_joy_direction(JOY_BUTTON_DPAD_DOWN, false))

	get_viewport().push_input(_joy_direction(JOY_BUTTON_DPAD_DOWN, true))
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), setup.bottom)


func test_top_modal_query_tracks_nested_ownership() -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var outer := Control.new()
	var outer_button := Button.new()
	outer.add_child(outer_button)
	add_child_autofree(outer)
	var inner := Control.new()
	var inner_button := Button.new()
	inner.add_child(inner_button)
	add_child_autofree(inner)
	assert_false(ux.is_top_modal(outer))
	ux.push_modal(outer, outer_button)
	assert_true(ux.is_top_modal(outer))
	ux.push_modal(inner, inner_button)
	assert_false(ux.is_top_modal(outer))
	assert_true(ux.is_top_modal(inner))
	ux.pop_modal(inner)
	assert_true(ux.is_top_modal(outer))


func test_suppressing_outer_clears_inner_hints_when_reexposed_then_restores_screen() -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var screen := Control.new()
	var screen_button := Button.new()
	screen.add_child(screen_button)
	add_child_autofree(screen)
	var screen_hints: Array[Dictionary] = [{action = &"confirm", label = "Screen", enabled = true}]
	screen_button.focus_entered.connect(func() -> void: ux.publish_hints(screen_hints))
	ux.register_screen(screen, screen_button)
	await get_tree().process_frame
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Screen")

	var outer := Control.new()
	var outer_button := Button.new()
	outer.add_child(outer_button)
	add_child_autofree(outer)
	ux.push_modal(outer, outer_button, true)
	assert_eq(ux.hint_bar.get_hint_count(), 0)

	var inner := Control.new()
	var inner_button := Button.new()
	inner.add_child(inner_button)
	add_child_autofree(inner)
	ux.push_modal(inner, inner_button)
	var inner_hints: Array[Dictionary] = [{action = &"cancel", label = "Inner", enabled = true}]
	ux.publish_hints(inner_hints)
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Inner")

	ux.pop_modal(inner)
	await get_tree().process_frame
	assert_true(ux.is_top_modal(outer))
	assert_eq(ux.hint_bar.get_hint_count(), 0)
	ux.pop_modal(outer)
	await get_tree().process_frame
	assert_eq(ux.get_focus_target(), screen_button)
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Screen")


func test_focusless_suppressing_modal_restores_unchanged_focus_hints_on_pop() -> void:
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var outer := Control.new()
	var outer_button := Button.new()
	outer.add_child(outer_button)
	add_child_autofree(outer)
	var outer_hints: Array[Dictionary] = [
		{action = &"confirm", label = "Select", enabled = true},
		{action = &"cancel", label = "Back", enabled = true},
	]
	outer_button.focus_entered.connect(func() -> void: ux.publish_hints(outer_hints))
	ux.push_modal(outer, outer_button)
	await get_tree().process_frame
	assert_eq(ux.hint_bar.get_hint(1).label.text, "Back")

	var inner := Control.new()
	var focusless_default := Button.new()
	inner.add_child(focusless_default)
	add_child_autofree(inner)
	ux.push_modal(inner, focusless_default, true, true)
	assert_null(get_viewport().gui_get_focus_owner())
	assert_null(ux.get_focus_target())
	assert_eq(ux.hint_bar.get_hint_count(), 0)

	ux.pop_modal(inner)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), outer_button)
	assert_eq(ux.hint_bar.get_hint_count(), 2)
	if ux.hint_bar.get_hint_count() >= 2:
		assert_eq(ux.hint_bar.get_hint(1).label.text, "Back")


func test_focusless_policy_change_releases_live_focus_and_cancels_stale_deferred_fallback() -> void:
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var screen := Control.new()
	var screen_button := Button.new()
	screen.add_child(screen_button)
	add_child_autofree(screen)
	ux.register_screen(screen, screen_button)
	await get_tree().process_frame
	var modal := Control.new()
	var modal_button := Button.new()
	modal.add_child(modal_button)
	add_child_autofree(modal)
	ux.push_modal(modal, modal_button)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), modal_button)

	screen_button.grab_focus()
	ux.update_modal_focus(modal, modal_button, true)
	assert_null(get_viewport().gui_get_focus_owner())
	assert_null(ux.get_focus_target())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(get_viewport().gui_get_focus_owner())
	assert_null(ux.get_focus_target())
	assert_false(modal_button.has_focus())

	ux.pop_modal(modal)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), screen_button)
	assert_same(ux.get_focus_target(), screen_button)
	assert_true(NavigationFocus._states.has(screen_button.get_instance_id()))


func test_focusless_modal_blocks_underlying_focus_navigation_and_keyboard_accept() -> void:
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var screen := Control.new()
	var first := Button.new()
	first.name = "First"
	var second := Button.new()
	second.name = "Second"
	first.focus_neighbor_bottom = NodePath("../Second")
	second.focus_neighbor_top = NodePath("../First")
	screen.add_child(first)
	screen.add_child(second)
	add_child_autofree(screen)
	ux.register_screen(screen, first)
	await get_tree().process_frame
	var underlying_pressed := [0]
	first.pressed.connect(func() -> void: underlying_pressed[0] += 1)
	second.pressed.connect(func() -> void: underlying_pressed[0] += 1)

	var modal := Control.new()
	var focusless_default := Button.new()
	focusless_default.focus_mode = Control.FOCUS_NONE
	modal.add_child(focusless_default)
	add_child_autofree(modal)
	ux.push_modal(modal, focusless_default, true, true)
	assert_null(get_viewport().gui_get_focus_owner())

	get_viewport().push_input(_key(KEY_DOWN))
	await get_tree().process_frame
	assert_null(get_viewport().gui_get_focus_owner())
	assert_false(second.has_focus())
	get_viewport().push_input(_key(KEY_ENTER))
	await get_tree().process_frame
	assert_eq(underlying_pressed[0], 0)
	assert_null(get_viewport().gui_get_focus_owner())

	ux.pop_modal(modal)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), first)


func test_open_modal_query_tracks_stack_presence() -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var modal := Control.new()
	var button := Button.new()
	modal.add_child(button)
	add_child_autofree(modal)
	assert_false(ux.has_open_modal())
	ux.push_modal(modal, button)
	assert_true(ux.has_open_modal())
	ux.pop_modal(modal)
	assert_false(ux.has_open_modal())


func test_remove_modal_discards_owned_presentation_without_restoring_screen() -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var screen := Control.new()
	var prior_screen_focus := Button.new()
	screen.add_child(prior_screen_focus)
	add_child_autofree(screen)
	ux.register_screen(screen, prior_screen_focus)
	await get_tree().process_frame
	var modal := Control.new()
	var modal_button := Button.new()
	modal.add_child(modal_button)
	add_child_autofree(modal)
	ux.push_modal(modal, modal_button)
	var modal_hints: Array[Dictionary] = [{action = &"cancel", label = "Back", enabled = true}]
	ux.publish_hints(modal_hints)
	await get_tree().process_frame

	ux.remove_modal(modal)

	assert_false(ux.is_top_modal(modal))
	assert_ne(ux.get_focus_target(), prior_screen_focus)
	assert_eq(ux.hint_bar.get_hint_count(), 0)
	ux.remove_modal(modal)
	ux.pop_modal(modal)
	assert_ne(ux.get_focus_target(), prior_screen_focus)

	var later_modal := Control.new()
	var later_button := Button.new()
	later_modal.add_child(later_button)
	add_child_autofree(later_modal)
	ux.push_modal(later_modal, later_button)
	ux.pop_modal(later_modal)
	await get_tree().process_frame
	assert_eq(ux.hint_bar.get_hint_count(), 0, "later modal lifecycle cannot restore removed-modal hints")


func test_removing_lower_modal_scrubs_its_hints_from_focusless_inner_restore() -> void:
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var screen := Control.new()
	var screen_button := Button.new()
	screen.add_child(screen_button)
	add_child_autofree(screen)
	var screen_hints: Array[Dictionary] = [{action = &"confirm", label = "Screen", enabled = true}]
	screen_button.focus_entered.connect(func() -> void: ux.publish_hints(screen_hints))
	ux.register_screen(screen, screen_button)
	await get_tree().process_frame

	var removed_modal := Control.new()
	var removed_default := Button.new()
	removed_default.focus_mode = Control.FOCUS_NONE
	removed_modal.add_child(removed_default)
	add_child_autofree(removed_modal)
	ux.push_modal(removed_modal, removed_default, false, true)
	ux.publish_hints([{action = &"cancel", label = "Removed", enabled = true}])

	var inner := Control.new()
	var inner_default := Button.new()
	inner_default.focus_mode = Control.FOCUS_NONE
	inner.add_child(inner_default)
	add_child_autofree(inner)
	ux.push_modal(inner, inner_default, false, true)
	ux.publish_hints([{action = &"confirm", label = "Inner", enabled = true}])
	ux.remove_modal(removed_modal)
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Inner")

	ux.pop_modal(inner)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), screen_button)
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Screen", "inner pop cannot resurrect removed-modal hints")


func test_remove_lower_modal_scrubs_descendant_restore_before_inner_pop() -> void:
	await _assert_removed_lower_modal_is_not_restored(false)


func test_remove_lower_modal_scrubs_root_restore_before_inner_pop() -> void:
	await _assert_removed_lower_modal_is_not_restored(true)


func test_remove_lower_modal_scrubs_owned_restore_screen_when_restore_expired() -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var prior_screen := Control.new()
	var prior_button := Button.new()
	prior_screen.add_child(prior_button)
	add_child_autofree(prior_screen)
	var prior_hints: Array[Dictionary] = [{action = &"confirm", label = "Prior", enabled = true}]
	prior_button.focus_entered.connect(func() -> void: ux.publish_hints(prior_hints))
	ux.register_screen(prior_screen, prior_button)
	var outer := Control.new()
	var saved_restore := Button.new()
	var outer_fallback := Button.new()
	outer.add_child(saved_restore)
	outer.add_child(outer_fallback)
	add_child_autofree(outer)
	ux.register_screen(outer, outer_fallback)
	prior_button.grab_focus()
	await get_tree().process_frame
	ux.push_modal(outer, saved_restore)
	var outer_hints: Array[Dictionary] = [{action = &"confirm", label = "Outer", enabled = true}]
	ux.publish_hints(outer_hints)
	var inner := Control.new()
	var inner_button := Button.new()
	inner.add_child(inner_button)
	add_child_autofree(inner)
	ux.push_modal(inner, inner_button)
	var inner_hints: Array[Dictionary] = [{action = &"cancel", label = "Inner", enabled = true}]
	ux.publish_hints(inner_hints)
	saved_restore.free()
	await get_tree().process_frame
	assert_false(is_instance_valid(saved_restore))

	ux.remove_modal(outer)

	assert_eq(ux.get_focus_target(), inner_button)
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Inner")
	ux.pop_modal(inner)
	await get_tree().process_frame
	assert_eq(ux.get_focus_target(), prior_button)
	assert_ne(get_viewport().gui_get_focus_owner(), outer_fallback)
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Prior")


func _assert_removed_lower_modal_is_not_restored(restore_root: bool) -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var screen := Control.new()
	var screen_button := Button.new()
	screen.add_child(screen_button)
	add_child_autofree(screen)
	var screen_hints: Array[Dictionary] = [{action = &"confirm", label = "Screen", enabled = true}]
	screen_button.focus_entered.connect(func() -> void: ux.publish_hints(screen_hints))
	ux.register_screen(screen, screen_button)
	await get_tree().process_frame
	var outer := Control.new()
	outer.focus_mode = Control.FOCUS_ALL
	var outer_button := Button.new()
	outer.add_child(outer_button)
	screen.add_child(outer)
	var inner := Control.new()
	var inner_button := Button.new()
	inner.add_child(inner_button)
	screen.add_child(inner)
	var outer_focus: Control = outer if restore_root else outer_button
	ux.push_modal(outer, outer_focus)
	var outer_hints: Array[Dictionary] = [{action = &"confirm", label = "Outer", enabled = true}]
	ux.publish_hints(outer_hints)
	ux.push_modal(inner, inner_button)
	var inner_hints: Array[Dictionary] = [{action = &"cancel", label = "Inner", enabled = true}]
	ux.publish_hints(inner_hints)
	await get_tree().process_frame

	ux.remove_modal(outer)

	assert_true(ux.is_top_modal(inner))
	assert_eq(ux.get_focus_target(), inner_button)
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Inner")
	ux.pop_modal(inner)
	await get_tree().process_frame
	assert_eq(ux.get_focus_target(), screen_button)
	assert_ne(get_viewport().gui_get_focus_owner(), outer_focus)
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Screen")


func test_party_menu_tree_teardown_does_not_restore_hub_or_publish_hints() -> void:
	var ux := UXScene.instantiate() as NavigationUXLayer
	ux.name = "NavigationUXLayer"
	add_child_autofree(ux)
	var saved_roster: Array[HeroData] = []
	saved_roster.assign(SaveSystem.party_roster)
	var hero := load("res://data/heroes/asher/asher.tres").duplicate(true) as HeroData
	SaveSystem.party_roster.assign([hero])
	var hub := HubScene.instantiate() as Hub
	add_child_autofree(hub)
	await get_tree().process_frame
	var party := hub.party_menu
	party.open()
	await get_tree().process_frame
	assert_true(ux.is_top_modal(party))

	hub.remove_child(party)
	await get_tree().process_frame

	assert_false(ux.is_top_modal(party))
	assert_ne(ux.get_focus_target(), hub.head_out_button)
	assert_eq(ux.hint_bar.get_hint_count(), 0)
	assert_engine_error_count(0)
	party.free()
	SaveSystem.party_roster.assign(saved_roster)


func test_registered_screens_track_focus_and_modal_restores_it() -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var screen_one := Control.new()
	var first := Button.new()
	screen_one.add_child(first)
	add_child_autofree(screen_one)
	var screen_two := Control.new()
	var second := Button.new()
	screen_two.add_child(second)
	add_child_autofree(screen_two)
	ux.register_screen(screen_one, first)
	ux.register_screen(screen_two, second)
	first.grab_focus()
	await get_tree().process_frame
	assert_eq(ux.get_focus_target(), first)
	var modal := Control.new()
	var modal_button := Button.new()
	modal.add_child(modal_button)
	add_child_autofree(modal)
	ux.push_modal(modal, modal_button)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), modal_button)
	second.grab_focus()
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), modal_button, "modal traps focus")
	ux.pop_modal(modal)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), first, "focus restored")
	assert_eq(screen_one.find_children("*NavigationCursor*", "", true, false).size(), 0)
	assert_eq(screen_two.find_children("*ActionHint*", "", true, false).size(), 0)


func test_modal_with_unavailable_default_falls_back_to_enabled_descendant() -> void:
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var outside := Button.new()
	add_child_autofree(outside)
	var modal := Control.new()
	var default_button := Button.new()
	var fallback_button := Button.new()
	modal.add_child(default_button)
	modal.add_child(fallback_button)
	add_child_autofree(modal)
	ux.push_modal(modal, default_button)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), default_button)

	default_button.disabled = true
	outside.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), fallback_button)
	assert_same(ux.get_focus_target(), fallback_button)


func test_modal_pop_synchronizes_restored_screen_focus_presentation() -> void:
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var screen := Control.new()
	var restored := Button.new()
	restored.position = Vector2(120, 70)
	restored.size = Vector2(80, 30)
	screen.add_child(restored)
	add_child_autofree(screen)
	ux.register_screen(screen, restored)
	await get_tree().process_frame
	var modal := Control.new()
	var modal_button := Button.new()
	modal.add_child(modal_button)
	add_child_autofree(modal)
	ux.push_modal(modal, modal_button)
	await get_tree().process_frame
	ux.pop_modal(modal)
	await get_tree().process_frame
	assert_eq(ux.get_focus_target(), restored)
	assert_true(NavigationFocus._states.has(restored.get_instance_id()))


func test_invalid_prior_focus_restores_registered_default_or_descendant() -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var screen := Control.new()
	var prior := Button.new()
	var fallback := Button.new()
	screen.add_child(prior)
	screen.add_child(fallback)
	add_child_autofree(screen)
	ux.register_screen(screen, fallback)
	prior.grab_focus()
	await get_tree().process_frame
	var modal := Control.new()
	var modal_button := Button.new()
	modal.add_child(modal_button)
	add_child_autofree(modal)
	ux.push_modal(modal, modal_button)
	prior.disabled = true
	ux.pop_modal(modal)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), fallback)


func test_nested_modals_restore_each_level_and_freed_modal_is_pruned() -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var screen := Control.new()
	var screen_button := Button.new()
	screen.add_child(screen_button)
	add_child_autofree(screen)
	ux.register_screen(screen, screen_button)
	var outer := Control.new()
	var outer_button := Button.new()
	outer.add_child(outer_button)
	add_child_autofree(outer)
	ux.push_modal(outer, outer_button)
	var inner := Control.new()
	var inner_button := Button.new()
	inner.add_child(inner_button)
	add_child(inner)
	ux.push_modal(inner, inner_button)
	ux.pop_modal(inner)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), outer_button)
	inner.free()
	outer.free()
	await get_tree().process_frame
	ux.ensure_valid_focus()
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), screen_button)


func test_unregister_prevents_restoration_into_removed_screen() -> void:
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var removed_screen := Control.new()
	var removed_button := Button.new()
	removed_screen.add_child(removed_button)
	add_child_autofree(removed_screen)
	var remaining_screen := Control.new()
	var remaining_button := Button.new()
	remaining_screen.add_child(remaining_button)
	add_child_autofree(remaining_screen)
	ux.register_screen(remaining_screen, remaining_button)
	ux.register_screen(removed_screen, removed_button)
	var modal := Control.new()
	var modal_button := Button.new()
	modal.add_child(modal_button)
	add_child_autofree(modal)
	ux.push_modal(modal, modal_button)
	ux.unregister_screen(removed_screen)
	ux.pop_modal(modal)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), remaining_button)


func test_never_registered_control_does_not_receive_global_presentation() -> void:
	InputManager._input(_pressed_joy_button())
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var outsider := Button.new()
	add_child_autofree(outsider)
	outsider.grab_focus()
	await get_tree().process_frame
	assert_null(ux.get_focus_target())
	assert_false(outsider.has_theme_stylebox_override(&"focus"))
	assert_false(ux.cursor.visible)


func test_unregister_last_screen_releases_focus_and_cursor() -> void:
	InputManager._input(_pressed_joy_button())
	var ux = UXScene.instantiate()
	add_child_autofree(ux)
	var screen := Control.new()
	var button := Button.new()
	screen.add_child(button)
	add_child_autofree(screen)
	ux.register_screen(screen, button)
	await get_tree().process_frame
	assert_eq(ux.get_focus_target(), button)
	ux.unregister_screen(screen)
	await get_tree().process_frame
	assert_null(ux.get_focus_target())
	assert_false(button.has_theme_stylebox_override(&"focus"))
	assert_false(ux.cursor.visible)


func _pressed_joy_button() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	return event
