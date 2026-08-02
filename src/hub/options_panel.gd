extends Control
class_name OptionsPanel

@onready var shake_slider: HSlider = $CenterContainer/VBoxContainer/ShakeRow/ShakeSlider
@onready var value_label: Label = $CenterContainer/VBoxContainer/ShakeRow/Value


func _ready() -> void:
	shake_slider.value_changed.connect(_on_shake_slider_value_changed)
	CombatPresentationSettings.shake_intensity_changed.connect(_on_shake_intensity_changed)
	_on_shake_intensity_changed(CombatPresentationSettings.shake_intensity)


func focus_default() -> Control:
	return shake_slider


func _on_shake_slider_value_changed(value: float) -> void:
	CombatPresentationSettings.set_shake_intensity(value)
	_update_value_label(CombatPresentationSettings.shake_intensity)


func _on_shake_intensity_changed(value: float) -> void:
	shake_slider.set_value_no_signal(value)
	_update_value_label(value)


func _update_value_label(value: float) -> void:
	value_label.text = "%d%%" % roundi(value * 100.0)
