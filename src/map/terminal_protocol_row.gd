extends Button
class_name TerminalProtocolRow

signal activated(choice_id: StringName)

@onready var caret_label: Label = %Caret
@onready var glyph: DynamicGlyph = %DynamicGlyph
@onready var title_label: Label = %Title
@onready var upgraded_label: Label = %Upgraded
@onready var outcome_label: Label = %Outcome

var _choice_id: StringName
var _action: StringName
var _mouse_hovered := false

func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_mode = Control.FOCUS_NONE
	_refresh_hover_presentation()

func configure(choice_id: StringName, action: StringName, title: String, outcome: String, upgraded: bool) -> void:
	_choice_id = choice_id
	_action = action
	title_label.text = title
	outcome_label.text = outcome
	upgraded_label.visible = upgraded
	glyph.set_action(action)

func set_interactable(enabled: bool) -> void:
	disabled = not enabled
	focus_mode = Control.FOCUS_NONE
	if not enabled:
		_mouse_hovered = false
	_refresh_hover_presentation()

func get_choice_id() -> StringName:
	return _choice_id

func get_action() -> StringName:
	return _action

func _on_pressed() -> void:
	if not disabled:
		activated.emit(_choice_id)

func _on_mouse_entered() -> void:
	_mouse_hovered = true
	_refresh_hover_presentation()

func _on_mouse_exited() -> void:
	_mouse_hovered = false
	_refresh_hover_presentation()

func _refresh_hover_presentation() -> void:
	if is_node_ready():
		caret_label.visible = _mouse_hovered and not disabled
