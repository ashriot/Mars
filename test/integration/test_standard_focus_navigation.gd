extends GutTest

const UXScene = preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const TitleScene = preload("res://src/core/title_screen.tscn")
const TerminalScene = preload("res://src/map/terminal.tscn")
const ResultScene = preload("res://src/map/dungeon_end_screen.tscn")
const HubScene = preload("res://src/hub/hub.tscn")
var _saved_roster: Array[HeroData] = []


func before_each() -> void:
	_saved_roster.assign(SaveSystem.party_roster)


func after_each() -> void:
	SaveSystem.party_roster.assign(_saved_roster)


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


func test_nested_party_and_terminal_cancel_only_top_and_restore_each_layer() -> void:
	var ux := _add_ux()
	var hero := load("res://data/heroes/asher/asher.tres").duplicate(true) as HeroData
	SaveSystem.party_roster.assign([hero])
	var hub := HubScene.instantiate() as Hub
	add_child_autofree(hub)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), hub.head_out_button)
	assert_false(hub.head_out_button.disabled)
	assert_true(hub.head_out_button.is_visible_in_tree())
	assert_eq(ux.get_focus_target(), hub.head_out_button)

	var party := hub.party_menu
	party.open()
	await get_tree().process_frame
	var party_default := party.mode_tabs.get_child(0) as Button
	assert_eq(get_viewport().gui_get_focus_owner(), party_default)
	assert_true(ux.is_top_modal(party))

	var inner := TerminalScene.instantiate()
	add_child_autofree(inner)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), inner.close_button)
	assert_true(ux.is_top_modal(inner))

	party._unhandled_input(_cancel_event())
	await get_tree().process_frame
	assert_true(party.visible, "lower modal ignores cancel while another modal owns the top")
	assert_true(ux.is_top_modal(inner))

	inner._unhandled_input(_cancel_event())
	await wait_seconds(0.3)
	assert_false(inner.visible)
	assert_true(party.visible)
	assert_true(ux.is_top_modal(party))
	assert_eq(get_viewport().gui_get_focus_owner(), party_default)
	assert_eq(ux.hint_bar.get_hint(1).label.text, "Back", "lower modal hints restore")

	party._unhandled_input(_cancel_event())
	await get_tree().process_frame
	assert_false(party.visible)
	assert_false(ux.is_top_modal(party))
	assert_eq(get_viewport().gui_get_focus_owner(), hub.head_out_button)
	assert_eq(ux.hint_bar.get_hint_count(), 1)
	assert_eq(ux.hint_bar.get_hint(0).label.text, "Select", "registered hub hints restore")
	assert_engine_error_count(0)


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
