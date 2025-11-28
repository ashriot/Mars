extends PanelContainer
class_name TooltipPanel

@onready var label: RichTextLabel = $Label

func set_text(text: String):
	label.text = text
	size = Vector2.ZERO
	custom_minimum_size.y = 0
	label.custom_minimum_size.y = 0
