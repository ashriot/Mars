extends Node

enum InputMode { KEYBOARD_MOUSE, CONTROLLER }
enum PresentationMode { POINTER, FOCUS }
# Temporary bridge for Tasks 3-5 while legacy navigation consumers migrate to PresentationMode.
enum CursorBehavior { FREE, SNAPPED }

const JOY_AXIS_THRESHOLD := 0.25
const HARDWARE_CURSOR := preload("res://assets/graphics/glyphs/cursors/outline/pointer_c.svg")
const HARDWARE_CURSOR_HOTSPOT := Vector2(2, 2)
const WARP_POSITION_TOLERANCE := 2.0
const WARP_SUPPRESSION_MS := 100
const DIRECTIONAL_NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_left", &"ui_right", &"ui_up", &"ui_down",
	&"nav_left", &"nav_right", &"nav_up", &"nav_down",
]

signal input_mode_changed(mode: InputMode)
signal controller_type_changed(type: InputIconMap.ControllerType)
signal presentation_mode_changed(mode: PresentationMode)
signal cursor_behavior_changed(behavior: CursorBehavior)

var _active_mode := InputMode.KEYBOARD_MOUSE
var _active_controller_type := InputIconMap.ControllerType.STEAM_DECK
var _presentation_mode := PresentationMode.POINTER
var _consumed_mouse_button: MouseButton = MOUSE_BUTTON_NONE
var _cursor_behavior := CursorBehavior.FREE
var _expected_warp_position := Vector2.INF
var _expected_warp_deadline_ms := 0


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_install_hardware_cursor(HARDWARE_CURSOR, HARDWARE_CURSOR_HOTSPOT)
	_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	update_controller_from_connected_names(_connected_device_names())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and _consumed_mouse_button != MOUSE_BUTTON_NONE:
		_mark_input_handled()
		if event.button_index == _consumed_mouse_button and not event.pressed:
			_consumed_mouse_button = MOUSE_BUTTON_NONE
		return
	if event is InputEventMouseMotion:
		if _suppress_expected_mouse_warp(event):
			return
		if _active_mode == InputMode.KEYBOARD_MOUSE and not event.relative.is_zero_approx():
			_set_presentation_mode(PresentationMode.POINTER)
		return
	if not is_meaningful_event(event):
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_set_active_mode(InputMode.CONTROLLER)
		_set_presentation_mode(PresentationMode.FOCUS)
		_set_cursor_behavior(CursorBehavior.SNAPPED)
		_set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		_set_active_controller_type(InputIconMap.get_controller_type_from_name(Input.get_joy_name(event.device)))
		return
	if event is InputEventKey:
		var previous_mode := _active_mode
		_set_active_mode(InputMode.KEYBOARD_MOUSE)
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if previous_mode == InputMode.CONTROLLER:
			_set_presentation_mode(PresentationMode.FOCUS)
		elif _presentation_mode == PresentationMode.POINTER and _is_directional_navigation_key(event):
			_set_presentation_mode(PresentationMode.FOCUS)
			_mark_input_handled()
		if _is_legacy_navigation_key(event):
			_set_cursor_behavior(CursorBehavior.SNAPPED)
		return
	if event is InputEventMouseButton:
		var previous_mode := _active_mode
		_set_active_mode(InputMode.KEYBOARD_MOUSE)
		_set_presentation_mode(PresentationMode.POINTER)
		_set_cursor_behavior(CursorBehavior.FREE)
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if previous_mode == InputMode.CONTROLLER:
			_consumed_mouse_button = event.button_index
			_mark_input_handled()


func get_active_mode() -> InputMode:
	return _active_mode


func restore_active_mode(mode: InputMode) -> void:
	_set_active_mode(mode)


func get_active_controller_type() -> InputIconMap.ControllerType:
	return _active_controller_type


func get_presentation_mode() -> PresentationMode:
	return _presentation_mode


func _set_presentation_mode(mode: PresentationMode) -> void:
	if _presentation_mode == mode:
		return
	_presentation_mode = mode
	presentation_mode_changed.emit(mode)


func get_cursor_behavior() -> CursorBehavior:
	return _cursor_behavior


func expect_mouse_warp(position: Vector2) -> void:
	_expected_warp_position = position
	_expected_warp_deadline_ms = _now_ms() + WARP_SUPPRESSION_MS


func is_meaningful_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) >= JOY_AXIS_THRESHOLD
	return false


func update_controller_from_connected_names(device_names: Array) -> void:
	var type := InputIconMap.ControllerType.STEAM_DECK
	if not device_names.is_empty():
		type = InputIconMap.get_controller_type_from_name(str(device_names[0]))
	_set_active_controller_type(type)


func handle_joy_connection_changed(connected_device_names: Array) -> void:
	update_controller_from_connected_names(connected_device_names)


func _on_joy_connection_changed(_device_id: int, _connected: bool) -> void:
	handle_joy_connection_changed(_connected_device_names())


func _connected_device_names() -> Array[String]:
	var names: Array[String] = []
	for device_id in Input.get_connected_joypads():
		names.append(Input.get_joy_name(device_id))
	return names


func _set_active_mode(mode: InputMode) -> void:
	_set_mouse_mode(Input.MOUSE_MODE_HIDDEN if mode == InputMode.CONTROLLER else Input.MOUSE_MODE_VISIBLE)
	if _active_mode == mode:
		return
	_active_mode = mode
	input_mode_changed.emit(mode)


func _set_cursor_behavior(behavior: CursorBehavior) -> void:
	# Legacy tests and callers use SNAPPED as a fresh controller-navigation claim.
	# Tasks 3-5 remove this reset together with the compatibility API.
	if behavior == CursorBehavior.SNAPPED:
		_consumed_mouse_button = MOUSE_BUTTON_NONE
	if _cursor_behavior == behavior:
		return
	_cursor_behavior = behavior
	cursor_behavior_changed.emit(behavior)


func _set_active_controller_type(type: InputIconMap.ControllerType) -> void:
	var resolved := InputIconMap.normalize_controller_type(type)
	_apply_family_bindings(resolved)
	if _active_controller_type == resolved:
		return
	_active_controller_type = resolved
	controller_type_changed.emit(resolved)


func _apply_family_bindings(type: InputIconMap.ControllerType) -> void:
	var bindings := InputIconMap.confirm_cancel_buttons(type)
	bindings[&"terminal_security"] = bindings[&"confirm"]
	for action: StringName in bindings:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				InputMap.action_erase_event(action, event)
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = bindings[action] as JoyButton
		InputMap.action_add_event(action, joy_event)


func _is_directional_navigation_key(event: InputEventKey) -> bool:
	for action in DIRECTIONAL_NAVIGATION_ACTIONS:
		if event.is_action(action):
			return true
	return false


func _is_legacy_navigation_key(event: InputEventKey) -> bool:
	for action in [
		&"ui_left", &"ui_right", &"ui_up", &"ui_down",
		&"nav_left", &"nav_right", &"nav_up", &"nav_down",
		&"confirm", &"cancel", &"page_left", &"page_right",
		&"role_left", &"role_right",
		&"action_1", &"action_2", &"action_3", &"action_4",
		&"terminal_security", &"terminal_medical", &"terminal_finance", &"terminal_scan", &"terminal_extract",
	]:
		if InputMap.has_action(action) and event.is_action(action):
			return true
	return false


func _suppress_expected_mouse_warp(event: InputEventMouseMotion) -> bool:
	if _expected_warp_position == Vector2.INF:
		return false
	var within_deadline := _now_ms() <= _expected_warp_deadline_ms
	var matches := within_deadline and event.position.distance_to(_expected_warp_position) <= WARP_POSITION_TOLERANCE
	if matches:
		return true
	_expected_warp_position = Vector2.INF
	_expected_warp_deadline_ms = 0
	return false


func _set_mouse_mode(mode: Input.MouseMode) -> void:
	Input.mouse_mode = mode


func _install_hardware_cursor(texture: Texture2D, hotspot: Vector2) -> void:
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _now_ms() -> int:
	return Time.get_ticks_msec()
