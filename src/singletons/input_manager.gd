extends Node

enum InputMode { KEYBOARD_MOUSE, CONTROLLER }
enum PresentationMode { POINTER, FOCUS }

const JOY_AXIS_THRESHOLD := 0.25
const HARDWARE_CURSOR := preload("res://assets/graphics/glyphs/cursors/outline/pointer_c.svg")
const HARDWARE_CURSOR_HOTSPOT := Vector2(2, 2)
const DIRECTIONAL_NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_left", &"ui_right", &"ui_up", &"ui_down",
	&"nav_left", &"nav_right", &"nav_up", &"nav_down",
]

signal input_mode_changed(mode: InputMode)
signal controller_type_changed(type: InputIconMap.ControllerType)
signal presentation_mode_changed(mode: PresentationMode)

var _active_mode := InputMode.KEYBOARD_MOUSE
var _active_controller_type := InputIconMap.ControllerType.STEAM_DECK
var _presentation_mode := PresentationMode.POINTER
var _consumed_mouse_button: MouseButton = MOUSE_BUTTON_NONE
var _processing_controller_direction := false


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_install_hardware_cursor(HARDWARE_CURSOR, HARDWARE_CURSOR_HOTSPOT)
	_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	handle_joy_connection_changed(_connected_device_names())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
		and event.button_index == _consumed_mouse_button \
		and _consumed_mouse_button != MOUSE_BUTTON_NONE:
		_mark_input_handled()
		if not event.pressed:
			_consumed_mouse_button = MOUSE_BUTTON_NONE
		return
	if event is InputEventMouseMotion:
		if _active_mode == InputMode.KEYBOARD_MOUSE and not event.relative.is_zero_approx():
			_set_presentation_mode(PresentationMode.POINTER)
		return
	if not is_meaningful_event(event):
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_processing_controller_direction = _is_directional_navigation_event(event)
		_set_active_mode(InputMode.CONTROLLER)
		_set_presentation_mode(PresentationMode.FOCUS)
		_set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		_set_active_controller_type(InputIconMap.get_controller_type_from_name(Input.get_joy_name(event.device)))
		_processing_controller_direction = false
		return
	if event is InputEventKey:
		var previous_mode := _active_mode
		_set_active_mode(InputMode.KEYBOARD_MOUSE)
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if previous_mode == InputMode.CONTROLLER:
			_set_presentation_mode(PresentationMode.FOCUS)
		elif _presentation_mode == PresentationMode.POINTER and _is_directional_navigation_event(event):
			_set_presentation_mode(PresentationMode.FOCUS)
			_mark_input_handled()
		return
	if event is InputEventMouseButton:
		var previous_mode := _active_mode
		_set_active_mode(InputMode.KEYBOARD_MOUSE)
		_set_presentation_mode(PresentationMode.POINTER)
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if previous_mode == InputMode.CONTROLLER:
			if _mouse_button_has_release(event.button_index):
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
	if connected_device_names.is_empty():
		return
	_set_active_mode(InputMode.CONTROLLER)
	_set_presentation_mode(PresentationMode.FOCUS)


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


func consume_controller_direction_for_focus_recovery() -> void:
	if _processing_controller_direction:
		_mark_input_handled()


func _is_directional_navigation_event(event: InputEvent) -> bool:
	for action in DIRECTIONAL_NAVIGATION_ACTIONS:
		if event.is_action(action):
			return true
	return false


func _mouse_button_has_release(button: MouseButton) -> bool:
	return button in [
		MOUSE_BUTTON_LEFT,
		MOUSE_BUTTON_RIGHT,
		MOUSE_BUTTON_MIDDLE,
		MOUSE_BUTTON_XBUTTON1,
		MOUSE_BUTTON_XBUTTON2,
	]


func _set_mouse_mode(mode: Input.MouseMode) -> void:
	Input.mouse_mode = mode


func _install_hardware_cursor(texture: Texture2D, hotspot: Vector2) -> void:
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()
