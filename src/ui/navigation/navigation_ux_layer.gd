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


func set_adapter(adapter: Object) -> void:
	_adapter = adapter


func publish_hints(hints: Array[Dictionary]) -> void:
	hint_bar.set_hints(hints)


func push_modal(root: Control, default_focus: Control) -> void:
	_modal_stack.append({"root": root, "restore": _focus_target})
	if _is_focusable(default_focus):
		default_focus.grab_focus()


func pop_modal(root: Control) -> void:
	if _modal_stack.is_empty() or _modal_stack.back().root != root:
		return
	var entry: Dictionary = _modal_stack.pop_back()
	var restore: Control = entry.restore
	if _is_focusable(restore):
		restore.grab_focus()


func get_focus_target() -> Control:
	return _focus_target


func _on_focus_changed(control: Control) -> void:
	if _restoring_focus:
		return
	if not _modal_stack.is_empty() and not _modal_stack.back().root.is_ancestor_of(control):
		var modal_root: Control = _modal_stack.back().root
		var fallback := _first_focusable(modal_root)
		if fallback:
			_restoring_focus = true
			fallback.grab_focus.call_deferred()
			_reset_restoring.call_deferred()
		return
	if is_instance_valid(_focus_target):
		NavigationFocus.clear(_focus_target)
	_focus_target = control
	if _is_focusable(control):
		NavigationFocus.apply(control)
		cursor.set_focus_target(control, control.get_meta("cursor_state", NavigationCursor.CursorState.DEFAULT))
	else:
		cursor.clear_target()


func _first_focusable(root: Control) -> Control:
	for child in root.find_children("*", "Control", true, false):
		if _is_focusable(child):
			return child
	return null


func _is_focusable(control: Control) -> bool:
	return is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and control.disabled)


func _reset_restoring() -> void:
	_restoring_focus = false
