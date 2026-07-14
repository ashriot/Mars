extends GutTest

const UXScene = preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const TitleScene = preload("res://src/core/title_screen.tscn")
const TerminalScene = preload("res://src/map/terminal.tscn")
const ResultScene = preload("res://src/map/dungeon_end_screen.tscn")
const HubScene = preload("res://src/hub/hub.tscn")
const PartyScene = preload("res://src/hub/party_menu.tscn")
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


func test_party_menu_authored_focus_neighbors_resolve_from_each_control() -> void:
	var party := PartyScene.instantiate() as PartyMenu
	add_child_autofree(party)
	var skills := party.get_node("Header/ModeTabs/Skills") as Button
	var inventory := party.get_node("Header/ModeTabs/Inventory") as Button
	var back := party.get_node("BackBtn") as Button
	assert_eq(skills.get_node_or_null(skills.focus_neighbor_left), back)
	assert_eq(skills.get_node_or_null(skills.focus_neighbor_right), inventory)
	assert_eq(inventory.get_node_or_null(inventory.focus_neighbor_left), skills)
	assert_eq(inventory.get_node_or_null(inventory.focus_neighbor_right), back)
	assert_eq(back.get_node_or_null(back.focus_neighbor_top), skills)
	assert_eq(back.get_node_or_null(back.focus_neighbor_bottom), skills)


func test_party_tabs_arrow_and_wasd_move_focus_and_cursor_to_same_destination() -> void:
	var ux := _add_ux()
	var hero := load("res://data/heroes/asher/asher.tres").duplicate(true) as HeroData
	SaveSystem.party_roster.assign([hero])
	var hub := HubScene.instantiate() as Hub
	add_child_autofree(hub)
	await get_tree().process_frame
	hub.party_menu.open()
	await get_tree().process_frame
	var skills := hub.party_menu.get_node("Header/ModeTabs/Skills") as Button
	var inventory := hub.party_menu.get_node("Header/ModeTabs/Inventory") as Button

	var destinations: Array[Vector2] = []
	for event: InputEventKey in [_key(KEY_RIGHT), _physical_key(KEY_D)]:
		skills.grab_focus()
		await get_tree().process_frame
		var focus_transitions: Array[Control] = []
		var record_focus := func(control: Control) -> void: focus_transitions.append(control)
		get_viewport().gui_focus_changed.connect(record_focus)
		InputManager._set_cursor_behavior(InputManager.CursorBehavior.FREE)
		get_viewport().push_input(event)
		await get_tree().process_frame
		get_viewport().gui_focus_changed.disconnect(record_focus)
		assert_same(get_viewport().gui_get_focus_owner(), inventory)
		assert_eq(focus_transitions, [inventory], "one focus transition per key press")
		assert_same(ux.get_focus_target(), inventory)
		assert_same(ux.cursor._target, inventory)
		assert_eq(InputManager.get_active_mode(), InputManager.InputMode.KEYBOARD_MOUSE)
		assert_eq(InputManager.get_cursor_behavior(), InputManager.CursorBehavior.SNAPPED)
		destinations.append(ux.cursor._target_position())
		event.pressed = false
		get_viewport().push_input(event)
		await get_tree().process_frame

	assert_eq(destinations.size(), 2)
	assert_eq(destinations[0], destinations[1])


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
	var underlying_pressed := [0]
	for button: BaseButton in party.find_children("*", "BaseButton", true, false):
		button.pressed.connect(func() -> void: underlying_pressed[0] += 1)
	assert_eq(get_viewport().gui_get_focus_owner(), party_default)
	assert_true(ux.is_top_modal(party))

	var inner := TerminalScene.instantiate()
	add_child_autofree(inner)
	assert_true(inner.setup({
		"upgrade_key": "",
		"bits": 12,
		"alert": 10,
		"facility_name": "NESTED",
		"session_id": "FOCUS-TEST",
	}))
	await get_tree().process_frame
	var first_protocol: TerminalProtocolRow = inner.get_protocol_row(0)
	assert_eq(first_protocol.focus_mode, Control.FOCUS_NONE)
	assert_false(first_protocol.has_focus())
	assert_null(get_viewport().gui_get_focus_owner())
	assert_null(ux.get_focus_target())
	assert_null(ux.cursor._target)
	assert_eq(ux.hint_bar.get_hint_count(), 0)
	assert_true(ux.is_top_modal(inner))
	var directional_event := _key(KEY_DOWN)
	get_viewport().push_input(directional_event)
	await get_tree().process_frame
	directional_event.pressed = false
	get_viewport().push_input(directional_event)
	await get_tree().process_frame
	var enter_event := _key(KEY_ENTER)
	get_viewport().push_input(enter_event)
	await get_tree().process_frame
	enter_event.pressed = false
	get_viewport().push_input(enter_event)
	await get_tree().process_frame
	assert_eq(underlying_pressed[0], 0, "keyboard accept cannot activate an obscured party control")
	assert_null(get_viewport().gui_get_focus_owner())
	for index in 5:
		var protocol_row: TerminalProtocolRow = inner.get_protocol_row(index)
		assert_false(protocol_row.has_focus())
		assert_false(protocol_row.caret_label.visible)
	assert_false(inner.close_button.has_focus())
	assert_ne(ux.cursor._target, inner.close_button)
	assert_true(inner.interaction_state in [inner.TerminalState.TYPING, inner.TerminalState.READY])
	inner.finish_typing()
	assert_eq(inner.interaction_state, inner.TerminalState.READY)
	enter_event.pressed = true
	get_viewport().push_input(enter_event)
	await get_tree().process_frame
	enter_event.pressed = false
	get_viewport().push_input(enter_event)
	await get_tree().process_frame
	assert_eq(underlying_pressed[0], 0, "keyboard accept remains blocked after terminal typing completes")
	assert_null(get_viewport().gui_get_focus_owner())
	assert_true(inner.handle_semantic_action(&"terminal_extract"))
	assert_true(ux.is_top_modal(inner))
	assert_true(inner.confirm_button.is_visible_in_tree())
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), inner.confirm_button)
	party_default.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), inner.confirm_button, "extraction confirmation recovers escaped focus")
	assert_same(ux.get_focus_target(), inner.confirm_button)
	assert_same(ux.cursor._target, inner.confirm_button)
	assert_true(inner.handle_semantic_action(&"cancel"))
	assert_eq(inner.interaction_state, inner.TerminalState.READY)
	assert_null(get_viewport().gui_get_focus_owner())
	assert_null(ux.get_focus_target())
	assert_null(ux.cursor._target)
	assert_false(inner.confirm_button.has_focus())
	assert_false(inner.cancel_button.has_focus())
	assert_false(inner.close_button.has_focus())
	for index in 5:
		assert_false(inner.get_protocol_row(index).has_focus())

	party._unhandled_input(_cancel_event())
	await get_tree().process_frame
	assert_true(party.visible, "lower modal ignores cancel while another modal owns the top")
	assert_true(ux.is_top_modal(inner))

	assert_not_null(inner.get_node_or_null("Panel/PanelContent/Footer/ExitHint"), "visible footer guidance stays coupled to terminal cancel")
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


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _physical_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event
