extends HBoxContainer
class_name ActionHint

@onready var glyph: TextureRect = $Glyph
@onready var label: Label = $Label
var action: StringName
var enabled := true


func configure(data: Dictionary) -> void:
	action = data.get("action", &"")
	enabled = data.get("enabled", true)
	label.text = data.get("label", "")
	modulate.a = 1.0 if enabled else 0.45


func refresh(mode: InputManager.InputMode, controller_type: InputIconMap.ControllerType) -> void:
	var resolved := InputIconMap.get_glyph(controller_type, action) if mode == InputManager.InputMode.CONTROLLER else null
	glyph.texture = resolved
	glyph.visible = resolved != null
