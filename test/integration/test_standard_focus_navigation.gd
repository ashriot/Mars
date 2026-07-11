extends GutTest

const UXScene = preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const TitleScene = preload("res://src/core/title_screen.tscn")
const TerminalScene = preload("res://src/map/terminal.tscn")
const ResultScene = preload("res://src/map/dungeon_end_screen.tscn")


func test_standard_screens_choose_enabled_visible_defaults() -> void:
	var ux := _add_ux()
	var title := TitleScene.instantiate() as TitleScreen
	add_child_autofree(title)
	await get_tree().process_frame
	var title_focus := get_viewport().gui_get_focus_owner()
	assert_true(title_focus == title.start_button or title_focus == title.continue_button)
	assert_false((title_focus as Button).disabled)
	assert_true(title_focus.is_visible_in_tree())
	assert_eq(ux.get_focus_target(), title_focus)

	var result := ResultScene.instantiate() as DungeonEndScreen
	add_child_autofree(result)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), result.continue_button)
	assert_eq(ux.get_focus_target(), result.continue_button)


func test_disabled_and_hidden_choices_are_excluded_from_navigation() -> void:
	var ux := _add_ux()
	var title := TitleScene.instantiate() as TitleScreen
	add_child_autofree(title)
	await get_tree().process_frame
	assert_ne(get_viewport().gui_get_focus_owner(), title.continue_button if title.continue_button.disabled else title.load_button)
	title.load_button.hide()
	title.load_button.grab_focus()
	ux.ensure_valid_focus()
	await get_tree().process_frame
	assert_ne(get_viewport().gui_get_focus_owner(), title.load_button)


func test_terminal_modal_traps_focus_and_cancel_dismisses_only_top_layer() -> void:
	var ux := _add_ux()
	var title := TitleScene.instantiate() as TitleScreen
	add_child_autofree(title)
	await get_tree().process_frame
	var prior_focus := get_viewport().gui_get_focus_owner()

	var outer := Control.new()
	add_child_autofree(outer)
	var inner := TerminalScene.instantiate()
	add_child_autofree(inner)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), inner.close_button)

	prior_focus.grab_focus()
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), inner.close_button, "top modal traps focus")

	inner._unhandled_input(_cancel_event())
	await wait_seconds(0.3)
	assert_false(inner.visible)
	assert_true(outer.visible, "cancel dismisses only the top modal")
	assert_eq(get_viewport().gui_get_focus_owner(), prior_focus, "focus restores to the prior valid control")
	assert_eq(ux.get_focus_target(), prior_focus)
	assert_eq(ux.hint_bar.get_hint_count(), 1)
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Select", "restored screen republishes its hints")
	# Task 4 records this duplicate one-shot connection as a final-review Minor.
	assert_engine_error("Signal 'tree_exiting' is already connected")


func _add_ux() -> NavigationUXLayer:
	var ux := UXScene.instantiate() as NavigationUXLayer
	ux.name = "NavigationUXLayer"
	add_child_autofree(ux)
	return ux


func _cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"cancel"
	event.pressed = true
	return event
