extends RefCounted
class_name NavigationFocus

const OVERRIDE_NAME := &"focus"
static var _states: Dictionary = {}


static func apply(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var key := control.get_instance_id()
	if not _states.has(key):
		_states[key] = {
			"control": weakref(control),
			"scale": control.scale,
			"pivot": control.pivot_offset,
			"had_override": control.has_theme_stylebox_override(OVERRIDE_NAME),
			"style": control.get_theme_stylebox(OVERRIDE_NAME) if control.has_theme_stylebox_override(OVERRIDE_NAME) else null,
			"tween": null,
		}
		control.tree_exiting.connect(_release_state.bind(key), CONNECT_ONE_SHOT)
	var state: Dictionary = _states[key]
	_kill_tween(state)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.75, 1.0, 0.12)
	style.border_color = Color(0.35, 0.9, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	control.add_theme_stylebox_override(OVERRIDE_NAME, style)
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	state.tween = tween
	tween.tween_property(control, "scale", state.scale * 1.03, 0.08)


static func clear(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var key := control.get_instance_id()
	if not _states.has(key):
		return
	var state: Dictionary = _states[key]
	_kill_tween(state)
	if state.had_override:
		control.add_theme_stylebox_override(OVERRIDE_NAME, state.style)
	else:
		control.remove_theme_stylebox_override(OVERRIDE_NAME)
	control.pivot_offset = state.pivot
	var tween := control.create_tween()
	state.tween = tween
	tween.tween_property(control, "scale", state.scale, 0.08)
	tween.finished.connect(_forget_state.bind(key))


static func _kill_tween(state: Dictionary) -> void:
	var tween: Tween = state.tween
	if is_instance_valid(tween):
		tween.kill()
	state.tween = null


static func _forget_state(key: int) -> void:
	_states.erase(key)


static func _release_state(key: int) -> void:
	if not _states.has(key):
		return
	var state: Dictionary = _states[key]
	_kill_tween(state)
	_states.erase(key)
