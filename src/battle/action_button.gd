extends Control
class_name ActionButton

@onready var label = $Title
@onready var button : Button = $Button
@onready var focus_pips = $FocusPips
@onready var panel := $Button/Panel
signal pressed(action_button: ActionButton)

var action : Action

func setup(_action: Action, cur_focus: int, color: Color):
	action = _action
	label.text = action.action_name
	update_cost()
	button.disabled = cur_focus < action.focus_cost
	self.modulate = color

func update_cost():
	var pips = focus_pips.get_children()
	for i in pips.size():
		if i < action.focus_cost:
			pips[i].visible = true
		else:
			pips[i].visible = false

func _on_button_pressed():
	pressed.emit()
