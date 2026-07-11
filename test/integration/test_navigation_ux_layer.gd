extends GutTest

const UXScene = preload("res://src/ui/navigation/navigation_ux_layer.tscn")


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
