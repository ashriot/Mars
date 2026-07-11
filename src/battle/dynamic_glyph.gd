extends TextureButton
class_name DynamicGlyph

@export var action: StringName = &"action_1"


func _ready() -> void:
	hide()


func set_action(new_action: StringName) -> void:
	action = new_action


func refresh(show_controller_glyph: bool, family: InputIconMap.ControllerType) -> void:
	if not show_controller_glyph:
		_clear_texture()
		return
	var glyph := InputIconMap.get_glyph(family, action)
	if glyph == null:
		_clear_texture()
		return
	texture_normal = glyph
	texture_pressed = glyph
	texture_disabled = glyph
	show()


func _clear_texture() -> void:
	texture_normal = null
	texture_pressed = null
	texture_disabled = null
	hide()
