extends CanvasLayer
class_name NavigationUXLayer

@onready var cursor: NavigationCursor = $NavigationCursor
@onready var hint_bar: ActionHintBar = $ActionHintBar

var _screens: Dictionary = {}
var _modal_stack: Array[Dictionary] = []
var _focus_target: Control
var _adapter: Object
var _restoring_focus := false


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_screen(root: Control, default_focus: Control = null) -> void:
	_screens[root] = default_focus
	if is_instance_valid(default_focus) and _is_focusable(default_focus):
		default_focus.grab_focus()


func unregister_screen(root: Control) -> void:
	_screens.erase(root)
	ensure_valid_focus()


func set_adapter(adapter: Object) -> void:
	_adapter = adapter


func publish_hints(hints: Array[Dictionary]) -> void:
	hint_bar.set_hints(hints)


func push_modal(root: Control, default_focus: Control) -> void:
	_prune_state()
	_modal_stack.append({
		"root": weakref(root),
		"default": weakref(default_focus),
		"restore": weakref(_focus_target) if is_instance_valid(_focus_target) else null,
		"restore_screen": weakref(_screen_for(_focus_target)) if is_instance_valid(_screen_for(_focus_target)) else null,
	})
	if _is_focusable(default_focus):
		default_focus.grab_focus()


func pop_modal(root: Control) -> void:
	_prune_state()
	if _modal_stack.is_empty() or _weak_get(_modal_stack.back().root) != root:
		return
	var entry: Dictionary = _modal_stack.pop_back()
	_restore_from_entry(entry)


func get_focus_target() -> Control:
	return _focus_target


func _on_focus_changed(control: Control) -> void:
	if _restoring_focus:
		return
	_prune_state()
	if not _modal_stack.is_empty():
		var modal_root := _weak_get(_modal_stack.back().root) as Control
		if modal_root == control or modal_root.is_ancestor_of(control):
			_update_focus_target(control)
			return
		var fallback := _modal_default(_modal_stack.back())
		if fallback:
			_grab_focus_deferred(fallback)
		return
	_update_focus_target(control)


func _update_focus_target(control: Control) -> void:
	if is_instance_valid(_focus_target):
		NavigationFocus.clear(_focus_target)
	_focus_target = control
	if _is_focusable(control):
		NavigationFocus.apply(control)
		cursor.set_focus_target(control, control.get_meta("cursor_state", NavigationCursor.CursorState.DEFAULT))
	else:
		cursor.clear_target()


func _first_focusable(root: Control) -> Control:
	if not is_instance_valid(root):
		return null
	if _is_focusable(root):
		return root
	for child in root.find_children("*", "Control", true, false):
		if _is_focusable(child):
			return child
	return null


func _is_focusable(control: Control) -> bool:
	return is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and control.disabled)


func _reset_restoring() -> void:
	_restoring_focus = false


func ensure_valid_focus() -> void:
	_prune_state()
	if not _modal_stack.is_empty():
		var modal_root := _weak_get(_modal_stack.back().root) as Control
		var owner := get_viewport().gui_get_focus_owner()
		if _is_focusable(owner) and (owner == modal_root or modal_root.is_ancestor_of(owner)):
			return
		var modal_focus := _modal_default(_modal_stack.back())
		if modal_focus:
			modal_focus.grab_focus()
		return
	var owner := get_viewport().gui_get_focus_owner()
	if _is_focusable(owner) and is_instance_valid(_screen_for(owner)):
		return
	var fallback := _registered_fallback()
	if fallback:
		fallback.grab_focus()


func _restore_from_entry(entry: Dictionary) -> void:
	var restore := _weak_get(entry.restore) as Control
	var restore_screen := _weak_get(entry.restore_screen) as Control
	if _is_focusable(restore) and is_instance_valid(_screen_for(restore)):
		restore.grab_focus()
		return
	if is_instance_valid(restore_screen) and _screens.has(restore_screen):
		var screen_fallback := _screen_fallback(restore_screen)
		if screen_fallback:
			screen_fallback.grab_focus()
			return
	var fallback := _registered_fallback()
	if fallback:
		fallback.grab_focus()


func _modal_default(entry: Dictionary) -> Control:
	var root := _weak_get(entry.root) as Control
	var default_focus := _weak_get(entry.default) as Control
	if _is_focusable(default_focus) and (default_focus == root or root.is_ancestor_of(default_focus)):
		return default_focus
	return _first_focusable(root)


func _screen_fallback(root: Control) -> Control:
	if not is_instance_valid(root) or not _screens.has(root):
		return null
	var default_focus: Control = _screens[root]
	if _is_focusable(default_focus) and (default_focus == root or root.is_ancestor_of(default_focus)):
		return default_focus
	return _first_focusable(root)


func _registered_fallback() -> Control:
	_prune_screens()
	for root in _screens:
		var fallback := _screen_fallback(root)
		if fallback:
			return fallback
	return null


func _screen_for(control: Control) -> Control:
	if not is_instance_valid(control):
		return null
	_prune_screens()
	for root in _screens:
		if root == control or root.is_ancestor_of(control):
			return root
	return null


func _prune_state() -> void:
	_prune_screens()
	for index in range(_modal_stack.size() - 1, -1, -1):
		if not is_instance_valid(_weak_get(_modal_stack[index].root)):
			_modal_stack.remove_at(index)


func _prune_screens() -> void:
	for root in _screens.keys():
		if not is_instance_valid(root):
			_screens.erase(root)


func _weak_get(reference: Variant) -> Variant:
	return reference.get_ref() if reference is WeakRef else null


func _grab_focus_deferred(control: Control) -> void:
	_restoring_focus = true
	control.grab_focus.call_deferred()
	_reset_restoring.call_deferred()
