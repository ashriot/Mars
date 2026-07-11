extends RefCounted
class_name NavigationFocus

const OVERRIDE_NAME := &"focus"


static func apply(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.75, 1.0, 0.12)
	style.border_color = Color(0.35, 0.9, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	control.add_theme_stylebox_override(OVERRIDE_NAME, style)
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(1.03, 1.03), 0.08)


static func clear(control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.remove_theme_stylebox_override(OVERRIDE_NAME)
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE, 0.08)
