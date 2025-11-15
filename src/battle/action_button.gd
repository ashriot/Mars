extends Control
class_name ActionButton

@onready var label = $Title
@onready var icon: TextureRect = $Icon
@onready var button : Button = $Button
@onready var focus_pips = $FocusPips
@onready var highlight_panel: Panel = $Highlight

signal pressed(action_button: ActionButton)

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
	update_cost()
	button.modulate = color
	icon.modulate = color
	label.modulate = color
	focus_pips.modulate = color
	highlight_panel.modulate = color
	$Glyph.modulate = color
	highlight_panel.hide()

func update_cost():
	var pips = focus_pips.get_children()
	for i in pips.size():
		if i < focus_cost:
			pips[i].visible = true
		else:
			pips[i].visible = false

func _on_button_pressed():
	pressed.emit()

func focused(value: bool):
	highlight_panel.visible = value
