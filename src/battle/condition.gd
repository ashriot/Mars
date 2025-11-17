extends Control
class_name ConditionUI

@onready var icon: TextureRect = $Panel/Icon

var condition: Condition


func setup(new_condition: Condition):
	condition = new_condition
	icon.texture = condition.icon
	var tooltip = condition.condition_name

	$Panel.tooltip_text = tooltip
