extends Control
class_name ActionButton

@onready var label = $Title
@onready var button = $Button
@onready var focus_pips = $FocusPips
signal pressed(action_button: ActionButton)

var action : Action

func setup(_action: Action):
	action = _action
	label.text = action.action_name
	update_cost()

func update_cost():
	var pips = focus_pips.get_children()
	for i in pips.size():
		if i < action.focus_cost:
			pips[i].visible = true
		else:
			pips[i].visible = false

func _on_button_pressed():
	pressed.emit()
