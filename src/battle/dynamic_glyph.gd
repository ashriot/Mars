extends TextureButton
class_name DynamicGlyph

@export var action: StringName = &"action_1"
var keyboard_label: Label


func _ready() -> void:
	_ensure_keyboard_label()
	InputManager.input_mode_changed.connect(_on_input_state_changed)
	InputManager.controller_type_changed.connect(_on_input_state_changed)
	_refresh_from_input_manager()


func set_action(new_action: StringName) -> void:
	action = new_action
	if is_inside_tree():
		_refresh_from_input_manager()


func refresh(show_controller_glyph: bool, family: InputIconMap.ControllerType) -> void:
	_ensure_keyboard_label()
	if show_controller_glyph:
		keyboard_label.hide()
		var glyph := InputIconMap.get_glyph(family, action)
		if glyph == null:
			_clear_presentation()
			return
		_set_texture(glyph)
		show()
		return

	_clear_texture()
	var label_text := InputIconMap.get_keyboard_label(action)
	if label_text.is_empty():
		_clear_presentation()
		return
	keyboard_label.text = label_text
	keyboard_label.show()
	show()


func _ensure_keyboard_label() -> void:
	if is_instance_valid(keyboard_label):
		return
	keyboard_label = Label.new()
	keyboard_label.name = "KeyboardLabel"
	keyboard_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	keyboard_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keyboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyboard_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keyboard_label.add_theme_font_size_override("font_size", 18)
	add_child(keyboard_label)


func _set_texture(glyph: Texture2D) -> void:
	texture_normal = glyph
	texture_pressed = glyph
	texture_disabled = glyph


func _clear_texture() -> void:
	texture_normal = null
	texture_pressed = null
	texture_disabled = null


func _clear_presentation() -> void:
	_clear_texture()
	keyboard_label.text = ""
	keyboard_label.hide()
	hide()


func _on_input_state_changed(_value: Variant) -> void:
	_refresh_from_input_manager()


func _refresh_from_input_manager() -> void:
	refresh(
		InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER,
		InputManager.get_active_controller_type(),
	)
