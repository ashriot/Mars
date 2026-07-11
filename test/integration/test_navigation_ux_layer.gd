extends GutTest

const UXScene = preload("res://src/ui/navigation/navigation_ux_layer.tscn")


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
