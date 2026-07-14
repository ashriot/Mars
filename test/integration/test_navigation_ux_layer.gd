extends GutTest

const UXScene = preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const HubScene = preload("res://src/hub/hub.tscn")

var saved_input_mode: InputManager.InputMode
var saved_cursor_behavior: InputManager.CursorBehavior
var saved_expected_warp_position: Vector2
var saved_expected_warp_deadline_ms: int


class RecordingCursor extends NavigationCursor:
	signal physical_warped(position: Vector2)
	var warped_positions: Array[Vector2] = []
	var expected_positions_at_warp: Array[Vector2] = []

	func _warp_mouse(position: Vector2) -> void:
		warped_positions.append(position)
		expected_positions_at_warp.append(InputManager._expected_warp_position)
		physical_warped.emit(position)


func before_each() -> void:
	saved_input_mode = InputManager._active_mode
	saved_cursor_behavior = InputManager._cursor_behavior
	saved_expected_warp_position = InputManager._expected_warp_position
	saved_expected_warp_deadline_ms = InputManager._expected_warp_deadline_ms


func after_each() -> void:
	InputManager._expected_warp_position = Vector2.INF
	InputManager._expected_warp_deadline_ms = 0
	InputManager._active_mode = saved_input_mode
	InputManager._cursor_behavior = saved_cursor_behavior
	InputManager._expected_warp_position = saved_expected_warp_position
	InputManager._expected_warp_deadline_ms = saved_expected_warp_deadline_ms


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
	focusless_default.focus_mode = Control.FOCUS_NONE
	inner.add_child(focusless_default)
	add_child_autofree(inner)
	ux.push_modal(inner, focusless_default, true)
	assert_same(get_viewport().gui_get_focus_owner(), outer_button)
	assert_eq(ux.hint_bar.get_hint_count(), 0)

	ux.pop_modal(inner)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), outer_button)
	assert_eq(ux.hint_bar.get_hint_count(), 2)
	if ux.hint_bar.get_hint_count() >= 2:
		assert_eq(ux.hint_bar.get_hint(1).label.text, "Back")


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


func test_modal_pop_synchronizes_cursor_to_restored_screen_focus() -> void:
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var original_cursor := ux.cursor
	original_cursor.set_process(false)
	ux.remove_child(original_cursor)
	original_cursor.free()
	var cursor := RecordingCursor.new()
	ux.add_child(cursor)
	ux.cursor = cursor
	cursor.set_process(false)
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
	InputManager._set_cursor_behavior(InputManager.CursorBehavior.SNAPPED)
	ux.pop_modal(modal)
	cursor.set_process(true)
	var recorded_warp: Vector2 = await cursor.physical_warped
	cursor.set_process(false)
	var destination := restored.get_global_transform_with_canvas() * (restored.size * 0.5)
	assert_eq(ux.get_focus_target(), restored)
	assert_eq(recorded_warp, destination)
	assert_eq(cursor.warped_positions, [destination])
	assert_eq(cursor.expected_positions_at_warp, [destination], "expect_mouse_warp runs before the physical warp seam")
	await get_tree().process_frame
	cursor.set_process(true)


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
