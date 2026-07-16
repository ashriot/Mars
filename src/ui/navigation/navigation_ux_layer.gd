extends CanvasLayer
class_name NavigationUXLayer

@onready var cursor: NavigationCursor = $NavigationCursor
@onready var hint_bar: ActionHintBar = $ActionHintBar
@onready var pointer_input_blocker: Control = $PointerInputBlocker

var _screens: Dictionary = {}
var _modal_stack: Array[Dictionary] = []
var _focus_target: Control
var _adapter: Object
var _restoring_focus := false
var _modal_focus_generation := 0
var _published_hints: Array[Dictionary] = []
var _published_hint_owner: WeakRef


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	InputManager.presentation_mode_changed.connect(_on_presentation_mode_changed)
	_on_presentation_mode_changed(InputManager.get_presentation_mode())
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_screen(root: Control, default_focus: Control = null) -> void:
	_screens[root] = default_focus
	if is_instance_valid(default_focus) and _is_focusable(default_focus):
		default_focus.grab_focus()


func unregister_screen(root: Control) -> void:
	var owned_focus := is_instance_valid(_focus_target) and _screen_for(_focus_target) == root
	_screens.erase(root)
	if owned_focus:
		_clear_presentation()
	if _modal_stack.is_empty():
		var fallback := _registered_fallback()
		if fallback:
			fallback.grab_focus()


func set_adapter(adapter: Object) -> void:
	if _adapter == adapter:
		return
	_adapter = adapter
	if is_instance_valid(_focus_target):
		NavigationFocus.clear(_focus_target)
	cursor.clear_hub_target()
	_focus_target = null


func publish_hints(hints: Array[Dictionary]) -> void:
	_prune_state()
	_published_hints.clear()
	_published_hints.assign(hints.duplicate(true))
	var owner := _active_presentation_owner()
	_published_hint_owner = weakref(owner) if is_instance_valid(owner) else null
	if _top_modal_suppresses_hints():
		hint_bar.set_hints([])
		return
	hint_bar.set_hints(_published_hints)


func push_modal(root: Control, default_focus: Control, suppress_hints := false, focusless := false) -> void:
	_prune_state()
	_modal_focus_generation += 1
	_modal_stack.append({
		"root": weakref(root),
		"default": weakref(default_focus),
		"restore": weakref(_focus_target) if is_instance_valid(_focus_target) else null,
		"restore_screen": weakref(_screen_for(_focus_target)) if is_instance_valid(_screen_for(_focus_target)) else null,
		"restore_hints": _published_hints.duplicate(true),
		"restore_hint_owner": _published_hint_owner,
		"suppress_hints": suppress_hints,
		"focusless": focusless,
		"focus_generation": _modal_focus_generation,
	})
	_apply_top_modal_hint_policy()
	if focusless:
		_enter_focusless_modal()
	elif _is_focusable(default_focus):
		default_focus.grab_focus()
		if _focus_target != default_focus:
			_update_focus_target(default_focus)


func update_modal_focus(root: Control, default_focus: Control, focusless := false) -> void:
	_prune_state()
	if _modal_stack.is_empty() or _weak_get(_modal_stack.back().root) != root:
		return
	_modal_focus_generation += 1
	_modal_stack.back().default = weakref(default_focus)
	_modal_stack.back().focusless = focusless
	_modal_stack.back().focus_generation = _modal_focus_generation
	if focusless:
		_enter_focusless_modal()
		return
	var modal_focus := _modal_default(_modal_stack.back())
	if modal_focus:
		modal_focus.grab_focus()
		if _focus_target != modal_focus:
			_update_focus_target(modal_focus)


func pop_modal(root: Control) -> void:
	_prune_state()
	if _modal_stack.is_empty() or _weak_get(_modal_stack.back().root) != root:
		return
	var entry: Dictionary = _modal_stack.pop_back()
	_published_hints.clear()
	var restore_hint_owner := _weak_get(entry.get("restore_hint_owner")) as Control
	if _is_active_presentation_owner(restore_hint_owner):
		_published_hints.assign(entry.get("restore_hints", []))
		_published_hint_owner = weakref(restore_hint_owner)
	else:
		_published_hint_owner = null
	_apply_top_modal_hint_policy()
	if not _top_modal_suppresses_hints():
		hint_bar.set_hints(_published_hints)
	_restore_from_entry(entry)


func remove_modal(root: Control) -> void:
	_prune_state()
	for index in range(_modal_stack.size() - 1, -1, -1):
		if _weak_get(_modal_stack[index].root) != root:
			continue
		var owns_focus := is_instance_valid(_focus_target) and (_focus_target == root or root.is_ancestor_of(_focus_target))
		_redirect_stale_restores(index, root)
		_modal_stack.remove_at(index)
		_discard_removed_hint_state(root)
		_apply_top_modal_hint_policy()
		if owns_focus:
			_clear_presentation()
			hint_bar.set_hints([])
		return


func _redirect_stale_restores(removed_index: int, removed_root: Control) -> void:
	var removed_entry: Dictionary = _modal_stack[removed_index]
	var replacement := _weak_get(removed_entry.restore) as Control
	if _belongs_to(replacement, removed_root):
		replacement = null
	var replacement_screen := _weak_get(removed_entry.restore_screen) as Control
	if not is_instance_valid(replacement_screen) or not _screens.has(replacement_screen) or _belongs_to(replacement_screen, removed_root):
		replacement_screen = null
	var replacement_hint_owner := _weak_get(removed_entry.get("restore_hint_owner")) as Control
	var replacement_hints: Array[Dictionary] = []
	if is_instance_valid(replacement_hint_owner) and replacement_hint_owner != removed_root:
		replacement_hints.assign(removed_entry.get("restore_hints", []))
	for index in range(removed_index + 1, _modal_stack.size()):
		var restore := _weak_get(_modal_stack[index].restore) as Control
		var restore_screen := _weak_get(_modal_stack[index].restore_screen) as Control
		var restore_is_removed := _belongs_to(restore, removed_root)
		var restore_screen_is_removed := _belongs_to(restore_screen, removed_root)
		if restore_is_removed or restore_screen_is_removed:
			_modal_stack[index].restore = weakref(replacement) if is_instance_valid(replacement) else null
			_modal_stack[index].restore_screen = weakref(replacement_screen) if is_instance_valid(replacement_screen) else null
		var restore_hint_owner := _weak_get(_modal_stack[index].get("restore_hint_owner")) as Control
		if restore_hint_owner == removed_root:
			_modal_stack[index].restore_hints = replacement_hints.duplicate(true)
			_modal_stack[index].restore_hint_owner = weakref(replacement_hint_owner) if is_instance_valid(replacement_hint_owner) else null


func _discard_removed_hint_state(removed_root: Control) -> void:
	if _weak_get(_published_hint_owner) != removed_root:
		return
	_published_hints.clear()
	_published_hint_owner = null
	if is_instance_valid(hint_bar):
		hint_bar.set_hints([])


func _belongs_to(control: Control, root: Control) -> bool:
	return is_instance_valid(control) and is_instance_valid(root) and (control == root or root.is_ancestor_of(control))


func is_top_modal(root: Control) -> bool:
	_prune_state()
	return not _modal_stack.is_empty() and _weak_get(_modal_stack.back().root) == root


func has_open_modal() -> bool:
	_prune_state()
	return not _modal_stack.is_empty()


func get_focus_target() -> Control:
	return _focus_target


func _on_focus_changed(control: Control) -> void:
	if _restoring_focus:
		return
	if is_instance_valid(_adapter) and _modal_stack.is_empty():
		return
	_prune_state()
	if not _modal_stack.is_empty():
		if bool(_modal_stack.back().get("focusless", false)):
			if is_instance_valid(control):
				_restoring_focus = true
				control.release_focus()
				_restoring_focus = false
			_clear_presentation()
			return
		var modal_root := _weak_get(_modal_stack.back().root) as Control
		if modal_root == control or modal_root.is_ancestor_of(control):
			_update_focus_target(control)
			return
		var fallback := _modal_default(_modal_stack.back())
		if fallback:
			_grab_focus_deferred(fallback)
		return
	if not is_instance_valid(_screen_for(control)):
		_clear_presentation()
		return
	_update_focus_target(control)


func _update_focus_target(control: Control) -> void:
	if is_instance_valid(_focus_target):
		NavigationFocus.clear(_focus_target)
	_focus_target = control
	if InputManager.get_presentation_mode() == InputManager.PresentationMode.FOCUS:
		_apply_focus_presentation(control)
	else:
		cursor.clear_hub_target()


func _apply_focus_presentation(control: Control) -> void:
	if not _is_focusable(control):
		cursor.clear_hub_target()
		return
	if _party_menu_for(control):
		NavigationFocus.apply_hub_hover(control)
		if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
			cursor.track_hub_target(control)
		else:
			cursor.clear_hub_target()
		return
	cursor.clear_hub_target()
	NavigationFocus.apply(control)


func _party_menu_for(control: Control) -> Control:
	var ancestor: Node = control
	while is_instance_valid(ancestor):
		if ancestor is Control and ancestor.name == &"PartyMenu":
			return ancestor as Control if (ancestor as Control).is_visible_in_tree() else null
		ancestor = ancestor.get_parent()
	return null


func _on_presentation_mode_changed(mode: InputManager.PresentationMode) -> void:
	pointer_input_blocker.visible = mode == InputManager.PresentationMode.FOCUS
	if mode == InputManager.PresentationMode.POINTER:
		if is_instance_valid(_focus_target):
			NavigationFocus.clear(_focus_target)
		cursor.clear_hub_target()
		return
	if InputManager.get_active_mode() == InputManager.InputMode.CONTROLLER:
		_refresh_pointer_hover.call_deferred()
	var had_valid_origin := _is_focusable(_focus_target)
	ensure_valid_focus()
	if not had_valid_origin and _is_focusable(_focus_target):
		InputManager.consume_controller_direction_for_focus_recovery()
	if _is_focusable(_focus_target):
		_apply_focus_presentation(_focus_target)


func _refresh_pointer_hover() -> void:
	if InputManager.get_active_mode() != InputManager.InputMode.CONTROLLER \
		or InputManager.get_presentation_mode() != InputManager.PresentationMode.FOCUS:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_mouse_position()
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)


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


func ensure_valid_focus() -> void:
	_prune_state()
	if is_instance_valid(_adapter) and _modal_stack.is_empty():
		return
	if not _modal_stack.is_empty():
		if bool(_modal_stack.back().get("focusless", false)):
			_enter_focusless_modal()
			return
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
	else:
		_clear_presentation()


func _restore_from_entry(entry: Dictionary) -> void:
	var restore := _weak_get(entry.restore) as Control
	var restore_screen := _weak_get(entry.restore_screen) as Control
	var top_modal_root: Control = null
	if not _modal_stack.is_empty():
		top_modal_root = _weak_get(_modal_stack.back().root) as Control
	if _is_focusable(restore) and (is_instance_valid(_screen_for(restore)) or _belongs_to(restore, top_modal_root)):
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
		return
	_restore_adapter_focus()


func _enter_focusless_modal() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if is_instance_valid(owner):
		_restoring_focus = true
		owner.release_focus()
		_restoring_focus = false
	_clear_presentation()


func _restore_adapter_focus() -> void:
	if not is_instance_valid(_adapter):
		_clear_presentation()
		return
	_focus_target = null
	if _adapter.has_method(&"navigation_focus_restored"):
		_adapter.call(&"navigation_focus_restored")


func _modal_default(entry: Dictionary) -> Control:
	if bool(entry.get("focusless", false)):
		return null
	var root := _weak_get(entry.root) as Control
	var default_focus := _weak_get(entry.default) as Control
	if _is_focusable(default_focus) and (default_focus == root or root.is_ancestor_of(default_focus)):
		return default_focus
	return _first_focusable(root)


func _active_presentation_owner() -> Control:
	if not _modal_stack.is_empty():
		return _weak_get(_modal_stack.back().root) as Control
	return _screen_for(_focus_target)


func _is_active_presentation_owner(owner: Control) -> bool:
	if not is_instance_valid(owner):
		return false
	if not _modal_stack.is_empty():
		return _weak_get(_modal_stack.back().root) == owner
	return _screens.has(owner)


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
	_apply_top_modal_hint_policy()


func _top_modal_suppresses_hints() -> bool:
	return not _modal_stack.is_empty() and bool(_modal_stack.back().get("suppress_hints", false))


func _apply_top_modal_hint_policy() -> void:
	if _top_modal_suppresses_hints() and is_instance_valid(hint_bar):
		hint_bar.set_hints([])


func _prune_screens() -> void:
	for root in _screens.keys():
		if not is_instance_valid(root):
			_screens.erase(root)


func _weak_get(reference: Variant) -> Variant:
	return reference.get_ref() if reference is WeakRef else null


func _grab_focus_deferred(control: Control) -> void:
	if _modal_stack.is_empty():
		return
	var entry: Dictionary = _modal_stack.back()
	_apply_deferred_modal_focus.call_deferred(
		entry.root,
		weakref(control),
		int(entry.get("focus_generation", -1)),
	)


func _apply_deferred_modal_focus(root_reference: WeakRef, control_reference: WeakRef, generation: int) -> void:
	_prune_state()
	if _modal_stack.is_empty():
		return
	var entry: Dictionary = _modal_stack.back()
	var root := _weak_get(root_reference) as Control
	var control := _weak_get(control_reference) as Control
	if (
		_weak_get(entry.root) != root
		or int(entry.get("focus_generation", -1)) != generation
		or bool(entry.get("focusless", false))
		or _modal_default(entry) != control
	):
		return
	_restoring_focus = true
	control.grab_focus()
	if get_viewport().gui_get_focus_owner() == control and _is_focusable(control):
		_update_focus_target(control)
	_restoring_focus = false


func _clear_presentation() -> void:
	if is_instance_valid(_focus_target):
		NavigationFocus.clear(_focus_target)
	cursor.clear_hub_target()
	_focus_target = null
