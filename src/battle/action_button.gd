extends Control
class_name ActionButton

@onready var label = $Title
@onready var icon: TextureRect = $Icon
@onready var button : Button = $Button
@onready var focus_pips = $FocusPips
@onready var highlight_panel: Panel = $Highlight

signal pressed(action_button: ActionButton)

var action : Action

func setup(_action: Action, cur_focus: int, color: Color):
	action = _action
	label.text = action.action_name
	icon.texture = action.icon
	update_cost()
	button.disabled = cur_focus < action.focus_cost
	button.modulate = color
	icon.modulate = color
	label.modulate = color
	focus_pips.modulate = color
	$Glyph.modulate = color
	highlight_panel.hide()

func update_cost():
	var pips = focus_pips.get_children()
	for i in pips.size():
		if i < action.focus_cost:
			pips[i].visible = true
		else:
			pips[i].visible = false

func _on_button_pressed():
	pressed.emit()

func _on_button_focus_entered():
	highlight_panel.show()

func _on_button_focus_exited():
	highlight_panel.hide()
