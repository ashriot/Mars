extends HBoxContainer
class_name ActionHint

@onready var glyph: TextureRect = $Glyph
@onready var label: Label = $Label
var action: StringName
var enabled := true
var _configuration: Dictionary = {}
var _refresh_pending := false
var _refresh_mode := InputManager.InputMode.KEYBOARD_MOUSE
var _refresh_controller_type := InputIconMap.ControllerType.STEAM_DECK


func _ready() -> void:
	_apply_configuration()
	if _refresh_pending:
		_apply_refresh()


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
	_refresh_pending = true
	_refresh_mode = mode
	_refresh_controller_type = controller_type
	if is_node_ready():
		_apply_refresh()


func _apply_refresh() -> void:
	if not is_instance_valid(glyph):
		return
	var resolved := InputIconMap.get_glyph(_refresh_controller_type, action) if _refresh_mode == InputManager.InputMode.CONTROLLER else null
	glyph.texture = resolved
	glyph.visible = resolved != null
