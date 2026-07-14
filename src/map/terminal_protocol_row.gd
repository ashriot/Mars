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

func _ready() -> void:
	pressed.connect(_on_pressed)
	focus_entered.connect(_refresh_focus_presentation)
	focus_exited.connect(_refresh_focus_presentation)
	_refresh_focus_presentation()

func configure(choice_id: StringName, action: StringName, title: String, outcome: String, upgraded: bool) -> void:
	_choice_id = choice_id
	_action = action
	title_label.text = title
	outcome_label.text = outcome
	upgraded_label.visible = upgraded
	glyph.set_action(action)

func set_interactable(enabled: bool) -> void:
	disabled = not enabled
	focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func get_choice_id() -> StringName:
	return _choice_id

func get_action() -> StringName:
	return _action

func _on_pressed() -> void:
	if not disabled:
		activated.emit(_choice_id)

func _refresh_focus_presentation() -> void:
	if is_node_ready():
		caret_label.visible = has_focus()
