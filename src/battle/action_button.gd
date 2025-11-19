extends Control
class_name ActionButton

signal pressed(action_button: ActionButton)

@onready var label = $Title
@onready var icon: TextureRect = $Mask/Icon
@onready var button : Button = $Button
@onready var focus_pips = $FocusPips
@onready var highlight_panel: Panel = $Highlight
@onready var dynamic_glyph: DynamicGlyph = $DynamicGlyph

@export_enum("SHIFT_LEFT", "SHIFT_RIGHT", "ACTION_1", "ACTION_2", "ACTION_3", "ACTION_4", "TARGET_UP", "TARGET_DOWN", "TARGET_LEFT", "TARGET_RIGHT") var associated_action: int = InputIconMap.Action.ACTION_1

var action : Action
var user_focus: int
var focus_cost: int
var disabled:
	set(value):
		button.disabled = value
		if action:
			if not value:
				button.disabled = user_focus < focus_cost
	get: return button.disabled


func setup(_action: Action, cur_focus: int, scaled_focus: int, color: Color):
	action = _action
	button.tooltip_text = action.description
	user_focus = cur_focus
	focus_cost = scaled_focus
	label.text = action.action_name
	icon.texture = action.icon
	update_cost(user_focus)
	button.modulate = color
	icon.modulate = color
	label.modulate = color
	focus_pips.modulate = color
	highlight_panel.modulate = color
	dynamic_glyph.modulate = color
	highlight_panel.hide()

func update_cost(current_focus: int):
	user_focus = current_focus
	var pips = focus_pips.get_children()
	var unfilled_pips = max(0, focus_cost - user_focus)
	for i in pips.size():
		var pip_node = pips[i]
		if i < focus_cost:
			pip_node.visible = true
			if i < unfilled_pips:
				pip_node.modulate.a = 0.33
			else:
				pip_node.modulate.a = 1.0
		else:
			pip_node.visible = false
	self.disabled = false

func _on_button_pressed():
	pressed.emit()

func focused(value: bool):
	highlight_panel.visible = value
