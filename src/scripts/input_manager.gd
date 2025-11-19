# InputManager.gd
extends Node

var active_controller_type = InputIconMap.ControllerType.PS
signal input_device_changed(new_type)

func _ready():
	# Detect controllers connected at startup
	var joy_name = Input.get_joy_name(0)
	if joy_name != "":
		active_controller_type = InputIconMap.get_controller_type_from_name(joy_name)

	# Connect signal to update when a controller is physically plugged/unplugged
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	# Emit initial signal for all glyphs to update
	input_device_changed.emit(active_controller_type)

func _input(event):
	# Check if the last input was from a controller or keyboard/mouse
	var new_type = active_controller_type # Start with current type

	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# A controller was used. Determine its type.
		var joy_name = Input.get_joy_name(event.device)
		new_type = InputIconMap.get_controller_type_from_name(joy_name)

	elif event is InputEventKey or event is InputEventMouseButton:
		# Keyboard or mouse was used. Switch to UNKNOWN (hides controller glyphs).
		new_type = InputIconMap.ControllerType.UNKNOWN

	# Only update and emit if the type actually changed
	if active_controller_type != new_type:
		active_controller_type = new_type
		input_device_changed.emit(active_controller_type)

func _on_joy_connection_changed(device_id: int, connected: bool):
	if connected:
		var joy_name = Input.get_joy_name(device_id)
		active_controller_type = InputIconMap.get_controller_type_from_name(joy_name)
	else:
		# If any controller is unplugged, re-check for other devices or assume UNKNOWN
		active_controller_type = InputIconMap.ControllerType.UNKNOWN
		# A more advanced version might iterate through all joypads here

	input_device_changed.emit(active_controller_type)
