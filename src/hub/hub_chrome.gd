extends RefCounted
class_name HubChrome

const BASE_STYLE_META := &"hub_chrome_base_style"
const STYLE_NAME_META := &"hub_chrome_style_name"
const ACTIVE_META := &"hub_chrome_active"


static func capture(surface: Control, style_name: StringName = &"panel") -> void:
	if not is_instance_valid(surface):
		return
	var style := surface.get_theme_stylebox(style_name) as StyleBoxFlat
	if style == null:
		return
	set_base_style(surface, style, style_name)


static func set_base_style(surface: Control, style: StyleBoxFlat, style_name: StringName = &"panel") -> void:
	if not is_instance_valid(surface) or style == null:
		return
	surface.set_meta(BASE_STYLE_META, style.duplicate())
	surface.set_meta(STYLE_NAME_META, style_name)
	set_active(surface, bool(surface.get_meta(ACTIVE_META, true)))


static func get_base_style(surface: Control) -> StyleBoxFlat:
	if not is_instance_valid(surface):
		return null
	if not surface.has_meta(BASE_STYLE_META):
		capture(surface)
	var base := surface.get_meta(BASE_STYLE_META, null) as StyleBoxFlat
	return base.duplicate() as StyleBoxFlat if base else null


static func set_active(surface: Control, active: bool, energy: float = 0.22) -> void:
	if not is_instance_valid(surface):
		return
	if not surface.has_meta(BASE_STYLE_META):
		capture(surface)
	var base := surface.get_meta(BASE_STYLE_META) as StyleBoxFlat
	if base == null:
		return
	surface.set_meta(ACTIVE_META, active)
	var style_name: StringName = surface.get_meta(STYLE_NAME_META, &"panel")
	var style := base.duplicate() as StyleBoxFlat
	if not active:
		style.border_color = _edge_color(base.border_color, energy)
		style.shadow_color = _edge_color(base.shadow_color, energy)
	surface.add_theme_stylebox_override(style_name, style)


static func _edge_color(color: Color, energy: float) -> Color:
	return Color(color.r * energy, color.g * energy, color.b * energy, color.a)
