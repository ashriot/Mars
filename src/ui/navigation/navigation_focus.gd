extends RefCounted
class_name NavigationFocus

const FOCUS_STYLE := preload("res://data/theme/styleboxes/button_focus.tres")
const FOCUS_FOREGROUND := Color(0.19607843, 0.19607843, 0.19607843, 1)
const HUB_PULSE_LOW_ALPHA := 0.45
const HUB_PULSE_HIGH_ALPHA := 0.80

static var _states: Dictionary = {}


static func apply(control: Control) -> void:
	if not is_instance_valid(control) or _states.has(control.get_instance_id()):
		return
	var surface := _resolve_surface(control)
	if not is_instance_valid(surface):
		return
	var style_name := &"focus" if surface is Button else &"panel"
	var labels: Array[Dictionary] = []
	for label in _focus_labels(control, surface):
		labels.append({
			"label": weakref(label),
			"had_override": label.has_theme_color_override(&"font_color"),
			"color": label.get_theme_color(&"font_color"),
			"had_outline_override": label.has_theme_constant_override(&"outline_size"),
			"outline_size": label.get_theme_constant(&"outline_size"),
		})
		label.add_theme_color_override(&"font_color", FOCUS_FOREGROUND)
		label.add_theme_constant_override(&"outline_size", 0)
	var focus := _focus_style_and_tween(control, surface)
	var state := {
		"control": weakref(control),
		"surface": weakref(surface),
		"style_name": style_name,
		"had_style_override": surface.has_theme_stylebox_override(style_name),
		"style": surface.get_theme_stylebox(style_name),
		"labels": labels,
		"had_font_focus_override": control.has_theme_color_override(&"font_focus_color"),
		"font_focus_color": control.get_theme_color(&"font_focus_color"),
	}
	if focus.has("tween"):
		state["tween"] = focus.tween
	var key := control.get_instance_id()
	_states[key] = state
	surface.add_theme_stylebox_override(style_name, focus.style)
	if control is Button:
		control.add_theme_color_override(&"font_focus_color", FOCUS_FOREGROUND)
	var cleanup := _release_state.bind(key)
	if not control.tree_exiting.is_connected(cleanup):
		control.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)


static func clear(control: Control) -> void:
	if not is_instance_valid(control) or not _states.has(control.get_instance_id()):
		return
	var key := control.get_instance_id()
	var state: Dictionary = _states[key]
	_kill_tween(state)
	var surface := state.surface.get_ref() as Control
	if is_instance_valid(surface):
		if state.had_style_override:
			surface.add_theme_stylebox_override(state.style_name, state.style)
		else:
			surface.remove_theme_stylebox_override(state.style_name)
	for label_state: Dictionary in state.labels:
		var label := label_state.label.get_ref() as Label
		if not is_instance_valid(label):
			continue
		if label_state.had_override:
			label.add_theme_color_override(&"font_color", label_state.color)
		else:
			label.remove_theme_color_override(&"font_color")
		if label_state.had_outline_override:
			label.add_theme_constant_override(&"outline_size", label_state.outline_size)
		else:
			label.remove_theme_constant_override(&"outline_size")
	if control is Button:
		if state.had_font_focus_override:
			control.add_theme_color_override(&"font_focus_color", state.font_focus_color)
		else:
			control.remove_theme_color_override(&"font_focus_color")
	_states.erase(key)


static func _release_state(key: int) -> void:
	if _states.has(key):
		_kill_tween(_states[key])
	_states.erase(key)


static func _focus_style_and_tween(control: Control, surface: Control) -> Dictionary:
	var style := FOCUS_STYLE.duplicate() as StyleBoxFlat
	if not bool(control.get_meta("navigation_focus_pulse", false)):
		return {"style": style}
	style.bg_color.a = HUB_PULSE_LOW_ALPHA
	var tween := surface.create_tween().set_loops()
	tween.tween_property(style, "bg_color:a", HUB_PULSE_HIGH_ALPHA, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(style, "bg_color:a", HUB_PULSE_LOW_ALPHA, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return {"style": style, "tween": tween}


static func _kill_tween(state: Dictionary) -> void:
	if not state.has("tween"):
		return
	var tween := state.tween as Tween
	if is_instance_valid(tween) and tween.is_valid():
		tween.kill()


static func _resolve_surface(control: Control) -> Control:
	if control.has_meta("navigation_focus_surface"):
		return control.get_node_or_null(control.get_meta("navigation_focus_surface")) as Control
	if control is Button or control is Panel or control is PanelContainer:
		return control
	return null


static func _focus_labels(control: Control, surface: Control) -> Array[Label]:
	var labels: Array[Label] = []
	for root in [control, surface]:
		for child in root.find_children("*", "Label", true, false):
			if child is Label and not child.get_meta("navigation_focus_exclude", false) and not labels.has(child):
				labels.append(child)
	return labels
