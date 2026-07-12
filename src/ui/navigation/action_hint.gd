extends HBoxContainer
class_name ActionHint

@onready var glyph: TextureRect = $Glyph
@onready var label: Label = $Label
var action: StringName
var enabled := true
var _configuration: Dictionary = {}


func _ready() -> void:
	_apply_configuration()


func configure(data: Dictionary) -> void:
	_configuration = data.duplicate(true)
	action = _configuration.get("action", &"")
	enabled = _configuration.get("enabled", true)
	if is_node_ready():
		_apply_configuration()


func _apply_configuration() -> void:
	if not is_instance_valid(label):
		return
	label.text = _configuration.get("label", "")
	modulate.a = 1.0 if enabled else 0.45


func refresh(mode: InputManager.InputMode, controller_type: InputIconMap.ControllerType) -> void:
	var resolved := InputIconMap.get_glyph(controller_type, action) if mode == InputManager.InputMode.CONTROLLER else null
	glyph.texture = resolved
	glyph.visible = resolved != null
