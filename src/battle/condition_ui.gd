extends Control
class_name ConditionUI

@onready var icon: TextureRect = $Panel/Mask/Icon
@onready var rich_tooltip: RichTooltip = $RichTooltip

var condition: Condition


func setup(new_condition: Condition):
	condition = new_condition
	icon.texture = condition.icon
	var tooltip = condition.condition_name.to_upper() +"\n" + condition.description

	rich_tooltip.bbcode_text = tooltip
