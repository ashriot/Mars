extends Node

enum InputMode { KEYBOARD_MOUSE, CONTROLLER }
enum CursorBehavior { FREE, SNAPPED }

const MOUSE_MOTION_THRESHOLD := 3.0
const JOY_AXIS_THRESHOLD := 0.25
const WARP_POSITION_TOLERANCE := 2.0
const WARP_SUPPRESSION_MS := 100
const NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_left", &"ui_right", &"ui_up", &"ui_down",
	&"nav_left", &"nav_right", &"nav_up", &"nav_down",
	&"confirm", &"cancel", &"page_left", &"page_right",
	&"role_left", &"role_right",
]

signal input_mode_changed(mode: InputMode)
signal controller_type_changed(type: InputIconMap.ControllerType)
signal cursor_behavior_changed(behavior: CursorBehavior)

var _active_mode := InputMode.KEYBOARD_MOUSE
var _active_controller_type := InputIconMap.ControllerType.STEAM_DECK
var _cursor_behavior := CursorBehavior.FREE
var _expected_warp_position := Vector2.INF
var _expected_warp_deadline_ms := 0


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	update_controller_from_connected_names(_connected_device_names())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _suppress_expected_mouse_warp(event):
		return
	if not is_meaningful_event(event):
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_set_active_mode(InputMode.CONTROLLER)
		_set_cursor_behavior(CursorBehavior.SNAPPED)
		_set_active_controller_type(InputIconMap.get_controller_type_from_name(Input.get_joy_name(event.device)))
	elif event is InputEventKey:
		_set_active_mode(InputMode.KEYBOARD_MOUSE)
		if _is_navigation_key(event):
			_set_cursor_behavior(CursorBehavior.SNAPPED)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_active_mode(InputMode.KEYBOARD_MOUSE)
		_set_cursor_behavior(CursorBehavior.FREE)


func get_active_mode() -> InputMode:
	return _active_mode


func get_active_controller_type() -> InputIconMap.ControllerType:
	return _active_controller_type


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
	if event is InputEventMouseMotion:
		return event.relative.length() > MOUSE_MOTION_THRESHOLD
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
	if _active_mode == mode:
		return
	_active_mode = mode
	input_mode_changed.emit(mode)


func _set_cursor_behavior(behavior: CursorBehavior) -> void:
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
	for action: StringName in [&"confirm", &"cancel"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				InputMap.action_erase_event(action, event)
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = bindings[action] as JoyButton
		InputMap.action_add_event(action, joy_event)


func _is_navigation_key(event: InputEventKey) -> bool:
	for action in NAVIGATION_ACTIONS:
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


func _now_ms() -> int:
	return Time.get_ticks_msec()
