extends Node

enum InputMode { MOUSE, KEYBOARD, CONTROLLER }

const MOUSE_MOTION_THRESHOLD := 3.0
const JOY_AXIS_THRESHOLD := 0.25

signal input_mode_changed(mode: InputMode)
signal controller_type_changed(type: InputIconMap.ControllerType)

var _active_mode := InputMode.MOUSE
var _active_controller_type := InputIconMap.ControllerType.STEAM_DECK


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	update_controller_from_connected_names(_connected_device_names())


func _input(event: InputEvent) -> void:
	if not is_meaningful_event(event):
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_set_active_mode(InputMode.CONTROLLER)
		_set_active_controller_type(InputIconMap.get_controller_type_from_name(Input.get_joy_name(event.device)))
	elif event is InputEventKey:
		_set_active_mode(InputMode.KEYBOARD)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_active_mode(InputMode.MOUSE)


func get_active_mode() -> InputMode:
	return _active_mode


func get_active_controller_type() -> InputIconMap.ControllerType:
	return _active_controller_type


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


func _set_active_controller_type(type: InputIconMap.ControllerType) -> void:
	if _active_controller_type == type:
		return
	_active_controller_type = type
	controller_type_changed.emit(type)
