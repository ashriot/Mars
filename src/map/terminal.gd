extends Control

signal option_selected(choice_id: StringName)
signal closed

enum TerminalState { TYPING, READY, CONFIRMING_EXTRACTION, CLOSING }

const PROTOCOL_ACTIONS: Array[StringName] = [
	&"terminal_security",
	&"terminal_medical",
	&"terminal_finance",
	&"terminal_scan",
]
const EXTRACTION_ACTION := &"terminal_extract"
const EXTRACTION_ID := &"opt_extract"
const MAX_PANEL_HEIGHT_RATIO := 0.9

@onready var panel: Control = %Panel
@onready var panel_content: Control = %PanelContent
@onready var close_button: TextureButton = %CloseButton
@onready var protocols: VBoxContainer = %Protocols
@onready var confirmation_panel: Control = %ConfirmationPanel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton
@onready var header_text: Label = %HeaderText
@onready var status_label: Label = %Status

var interaction_state := TerminalState.TYPING
var type_tween: Tween
var close_tween: Tween
var _lifecycle_generation := 0
var _presentation_valid := false
var _rows: Array[TerminalProtocolRow] = []
var _typing_labels: Array[Label] = []


func _ready() -> void:
	for child in protocols.get_children():
		if child is TerminalProtocolRow:
			_rows.append(child)
			(child as TerminalProtocolRow).activated.connect(_on_protocol_activated)
	_typing_labels.assign([header_text, status_label, %Prompt, %TraceWarning])
	close_button.pressed.connect(func() -> void: handle_semantic_action(&"cancel"))
	confirm_button.pressed.connect(func() -> void: handle_semantic_action(&"confirm"))
	cancel_button.pressed.connect(func() -> void: handle_semantic_action(&"cancel"))
	_ensure_modal_registered()
	get_viewport().size_changed.connect(_fit_panel_to_content)
	_fit_panel_to_content.call_deferred()


func _exit_tree() -> void:
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.remove_modal(self)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var navigation := _navigation_ux_layer()
	if navigation and not navigation.is_top_modal(self):
		return
	var viewport := get_viewport()
	var actions: Array[StringName] = [&"cancel", &"confirm", EXTRACTION_ACTION]
	actions.append_array(PROTOCOL_ACTIONS)
	for action: StringName in actions:
		if event.is_action_pressed(action) and handle_semantic_action(action):
			viewport.set_input_as_handled()
			return


func setup(data: Dictionary) -> bool:
	_reset_lifecycle()
	_ensure_modal_registered()
	_presentation_valid = _has_valid_presentation_data(data)
	if not _presentation_valid:
		header_text.text = "PARADIGM TERMINAL // DATA ERROR"
		status_label.text = "PROTOCOL DIRECTORY UNAVAILABLE"
		_set_rows_interactable(false)
		interaction_state = TerminalState.READY
		_fit_panel_to_content.call_deferred()
		return false
	var definitions := _protocol_definitions(data)
	for index in 5:
		var definition: Dictionary = definitions[index]
		_rows[index].configure(
			definition.id,
			definition.action,
			definition.title,
			definition.outcome,
			definition.upgraded,
		)
		_rows[index].set_interactable(true)
	header_text.text = "PARADIGM TERMINAL v4.2 // %s" % str(data.facility_name)
	status_label.text = "NEURAL AUTH: SUCCESS · FIREWALL: OFF · SESSION %s" % str(data.session_id)
	interaction_state = TerminalState.TYPING
	_start_typing_effect()
	_fit_panel_to_content.call_deferred()
	return true


func _fit_panel_to_content() -> void:
	if not is_inside_tree() or not is_instance_valid(panel) or not is_instance_valid(panel_content):
		return
	var viewport_height := float(get_viewport_rect().size.y)
	var desired_height := panel_content.get_combined_minimum_size().y
	var fitted_height := minf(desired_height, viewport_height * MAX_PANEL_HEIGHT_RATIO)
	panel.offset_top = -fitted_height * 0.5
	panel.offset_bottom = fitted_height * 0.5


func handle_semantic_action(action: StringName) -> bool:
	if interaction_state == TerminalState.CLOSING:
		return action in PROTOCOL_ACTIONS or action in [EXTRACTION_ACTION, &"confirm", &"cancel"]
	if not _presentation_valid:
		if action == &"cancel":
			_begin_close()
			return true
		return action in PROTOCOL_ACTIONS or action in [EXTRACTION_ACTION, &"confirm"]
	if interaction_state == TerminalState.TYPING:
		if action == &"cancel":
			_begin_close()
			return true
		return action in PROTOCOL_ACTIONS or action in [EXTRACTION_ACTION, &"confirm"]
	if interaction_state == TerminalState.CONFIRMING_EXTRACTION:
		if action == &"confirm":
			_commit_choice(EXTRACTION_ID)
			return true
		if action == &"cancel":
			_leave_extraction_confirmation()
			return true
		return action in PROTOCOL_ACTIONS or action == EXTRACTION_ACTION
	if action == &"cancel":
		_begin_close()
		return true
	if action == EXTRACTION_ACTION:
		_enter_extraction_confirmation()
		return true
	var action_index := PROTOCOL_ACTIONS.find(action)
	if action_index >= 0:
		_commit_choice(_rows[action_index].get_choice_id())
		return true
	return false


func finish_typing() -> void:
	if interaction_state != TerminalState.TYPING:
		return
	if is_instance_valid(type_tween):
		type_tween.kill()
	for label: Label in _typing_labels:
		label.visible_ratio = 1.0
	for row: TerminalProtocolRow in _rows:
		row.modulate.a = 1.0
	interaction_state = TerminalState.READY


func get_protocol_row(index: int) -> TerminalProtocolRow:
	return _rows[index] if index >= 0 and index < _rows.size() else null


func _protocol_definitions(data: Dictionary) -> Array[Dictionary]:
	var upgrade_key: String = data.upgrade_key
	return [
		{id = &"opt_sec_up" if upgrade_key == "security" else &"opt_sec", action = &"terminal_security", title = "REBOOT SECURITY" if upgrade_key == "security" else "SCRAMBLE CAMERAS", outcome = "ALERT -%d%%" % int(data.alert), upgraded = upgrade_key == "security"},
		{id = &"opt_med_up" if upgrade_key == "medical" else &"opt_med", action = &"terminal_medical", title = "DISPENSE ADRENALINE" if upgrade_key == "medical" else "DISPENSE PAINKILLERS", outcome = "HEAL + BOOST" if upgrade_key == "medical" else "HEAL INJURY", upgraded = upgrade_key == "medical"},
		{id = &"opt_fin_up" if upgrade_key == "finance" else &"opt_fin", action = &"terminal_finance", title = "INTERCEPT PAYMENT" if upgrade_key == "finance" else "BIT MINE", outcome = "+%.1f BITS" % (float(data.bits) / 10.0), upgraded = upgrade_key == "finance"},
		{id = &"opt_scan_up" if upgrade_key == "scan" else &"opt_scan", action = &"terminal_scan", title = "HIJACK CAMERA NETWORK" if upgrade_key == "scan" else "HIJACK LOCAL FEED", outcome = "WIDE SCAN" if upgrade_key == "scan" else "SECTOR SCAN", upgraded = upgrade_key == "scan"},
		{id = EXTRACTION_ID, action = EXTRACTION_ACTION, title = "SIGNAL EXTRACTION", outcome = "TACTICAL RETREAT", upgraded = false},
	]


func _has_valid_presentation_data(data: Dictionary) -> bool:
	for field in ["upgrade_key", "bits", "alert", "facility_name", "session_id"]:
		if not data.has(field):
			return false
	return (
		data.upgrade_key is String
		and (data.bits is int or data.bits is float)
		and (data.alert is int or data.alert is float)
		and data.facility_name is String
		and data.session_id is String
	)


func _reset_lifecycle() -> void:
	_lifecycle_generation += 1
	for tween: Tween in [type_tween, close_tween]:
		if is_instance_valid(tween):
			tween.kill()
	type_tween = null
	close_tween = null
	modulate.a = 1.0
	show()
	confirmation_panel.hide()
	close_button.disabled = false
	confirm_button.disabled = false
	cancel_button.disabled = false
	for label: Label in _typing_labels:
		label.visible_ratio = 1.0
	for row: TerminalProtocolRow in _rows:
		row.modulate.a = 1.0


func _start_typing_effect() -> void:
	for label: Label in _typing_labels:
		label.visible_ratio = 0.0
	for row: TerminalProtocolRow in _rows:
		row.modulate.a = 0.15
	type_tween = create_tween().set_parallel(true)
	for label: Label in _typing_labels:
		type_tween.tween_property(label, "visible_ratio", 1.0, 0.3)
	for row: TerminalProtocolRow in _rows:
		type_tween.tween_property(row, "modulate:a", 1.0, 0.35)
	type_tween.chain().tween_callback(finish_typing)


func _set_rows_interactable(enabled: bool) -> void:
	for row: TerminalProtocolRow in _rows:
		row.set_interactable(enabled)


func _enter_extraction_confirmation() -> void:
	interaction_state = TerminalState.CONFIRMING_EXTRACTION
	_set_rows_interactable(false)
	confirmation_panel.show()
	var navigation := _navigation_ux_layer()
	if navigation and navigation.is_top_modal(self):
		navigation.update_modal_focus(self, confirm_button)
	else:
		_grab_focus_if_valid.call_deferred(confirm_button)


func _leave_extraction_confirmation() -> void:
	var navigation := _navigation_ux_layer()
	if navigation and navigation.is_top_modal(self):
		navigation.update_modal_focus(self, _rows[0], true)
	confirmation_panel.hide()
	_set_rows_interactable(true)
	interaction_state = TerminalState.READY


func _commit_choice(choice_id: StringName) -> void:
	if interaction_state == TerminalState.CLOSING:
		return
	interaction_state = TerminalState.CLOSING
	_set_rows_interactable(false)
	close_button.disabled = true
	confirm_button.disabled = true
	cancel_button.disabled = true
	AudioManager.play_sfx("terminal")
	option_selected.emit(choice_id)
	_animate_close(false)


func _begin_close() -> void:
	if interaction_state == TerminalState.CLOSING:
		return
	interaction_state = TerminalState.CLOSING
	_set_rows_interactable(false)
	close_button.disabled = true
	confirm_button.disabled = true
	cancel_button.disabled = true
	_animate_close(true)


func _animate_close(emit_closed: bool) -> void:
	var close_generation := _lifecycle_generation
	close_tween = create_tween()
	close_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await close_tween.finished
	if close_generation != _lifecycle_generation:
		return
	close_tween = null
	hide()
	var navigation := _navigation_ux_layer()
	if navigation and navigation.is_top_modal(self):
		navigation.pop_modal(self)
	if emit_closed:
		closed.emit()
	else:
		queue_free()


func _on_protocol_activated(choice_id: StringName) -> void:
	if not _presentation_valid:
		return
	if interaction_state == TerminalState.TYPING:
		return
	if interaction_state != TerminalState.READY:
		return
	if choice_id == EXTRACTION_ID:
		_enter_extraction_confirmation()
	else:
		_commit_choice(choice_id)


func _ensure_modal_registered() -> void:
	var navigation := _navigation_ux_layer()
	if not navigation:
		return
	if not navigation.is_top_modal(self):
		navigation.push_modal(self, _rows[0], true, true)
	else:
		navigation.update_modal_focus(self, _rows[0], true)


func _navigation_ux_layer() -> NavigationUXLayer:
	return get_tree().root.find_child("NavigationUXLayer", true, false) as NavigationUXLayer


func _grab_focus_if_valid(control: Control) -> void:
	if (
		is_instance_valid(control)
		and control.is_inside_tree()
		and control.is_visible_in_tree()
		and not (control is BaseButton and control.disabled)
	):
		control.grab_focus()
