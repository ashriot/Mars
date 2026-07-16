extends TextureButton
class_name DynamicGlyph

@export var action: StringName = &"action_1"
@export var controller_only := false
@export var fade_duration := 0.18
var _fade_tween: Tween


func _ready() -> void:
	InputManager.input_mode_changed.connect(_on_input_state_changed)
	InputManager.controller_type_changed.connect(_on_input_state_changed)
	_refresh_from_input_manager()


func set_action(new_action: StringName) -> void:
	action = new_action
	if is_inside_tree():
		_refresh_from_input_manager()


func _exit_tree() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()


func refresh(show_controller_glyph: bool, family: InputIconMap.ControllerType) -> void:
	if controller_only:
		var glyph := InputIconMap.get_glyph(family, action)
		if glyph == null:
			_clear_texture()
			return
		_set_texture(glyph)
		show()
		_fade_to(1.0 if show_controller_glyph else 0.0)
		return
	var resolved_family := family if show_controller_glyph else InputIconMap.ControllerType.KEYBOARD_MOUSE
	var glyph := InputIconMap.get_glyph(resolved_family, action)
	if glyph == null:
		_clear_texture()
		return
	_set_texture(glyph)
	show()
	modulate.a = 1.0


func _set_texture(glyph: Texture2D) -> void:
	texture_normal = glyph
	texture_pressed = glyph
	texture_disabled = glyph


func _fade_to(alpha: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if fade_duration <= 0.0:
		modulate.a = alpha
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _clear_texture() -> void:
	texture_normal = null
	texture_pressed = null
	texture_disabled = null
	modulate.a = 0.0 if controller_only else 1.0
	hide()


func _on_input_state_changed(_value: Variant) -> void:
	_refresh_from_input_manager()


func _refresh_from_input_manager() -> void:
	refresh(
		InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER,
		InputManager.get_active_controller_type(),
	)
