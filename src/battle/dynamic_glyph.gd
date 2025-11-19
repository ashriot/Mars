extends TextureButton
class_name DynamicGlyph

@export var parent_node: Control
@export_enum("SHIFT_LEFT", "SHIFT_RIGHT", "ACTION_1", "ACTION_2", "ACTION_3", "ACTION_4", "TARGET_UP", "TARGET_DOWN", "TARGET_LEFT", "TARGET_RIGHT") var associated_action: int = InputIconMap.Action.ACTION_1

func _ready():
	# Use the Singleton name directly: InputManager
	InputManager.input_device_changed.connect(_on_input_device_changed)
	if parent_node:
		associated_action = parent_node.associated_action

	# Run the update once at startup
	#_on_input_device_changed(InputManager.active_controller_type)
	hide()

func _on_input_device_changed(new_type: InputIconMap.ControllerType):
	if new_type != InputIconMap.ControllerType.UNKNOWN:
		# Use the Singleton name directly: InputIconMap
		var action_data = InputIconMap.GLYPHS[new_type][associated_action]

		self.texture_normal = action_data.normal
		self.texture_pressed = action_data.pressed

		self.visible = true
	else:
		self.visible = false
