extends RefCounted
class_name NavigationFocus

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
			"tween": null,
		}
		var cleanup := _release_state.bind(key)
		if not control.tree_exiting.is_connected(cleanup):
			control.tree_exiting.connect(cleanup, CONNECT_ONE_SHOT)
	var state: Dictionary = _states[key]
	_kill_tween(state)
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
