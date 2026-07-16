extends PanelContainer
class_name TooltipPanel

@onready var label: RichTextLabel = $Label


func _ready() -> void:
	get_viewport().size_changed.connect(_refit_width)
	_refit_width()


func set_text(text: String) -> void:
	label.text = text
	custom_minimum_size.y = 0
	label.custom_minimum_size.y = 0
	reset_size()


func _refit_width() -> void:
	var available_width := maxf(get_viewport_rect().size.x - 96.0, 0.0)
	label.custom_minimum_size.x = minf(600.0, available_width)
	reset_size()
