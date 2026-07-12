extends TextureRect
class_name NavigationCursor

enum CursorState { DEFAULT, INTERACT, CAN_GRAB, DRAGGING, UPGRADE, DISABLED, BUSY, TARGET, MODIFY }

const STATE_FILES := {
	CursorState.DEFAULT: "pointer_c.svg",
	CursorState.INTERACT: "hand_point.svg",
	CursorState.CAN_GRAB: "hand_open.svg",
	CursorState.DRAGGING: "hand_closed.svg",
	CursorState.UPGRADE: "tool_hammer.svg",
	CursorState.DISABLED: "cursor_disabled.svg",
	CursorState.BUSY: "busy_circle.svg",
	CursorState.TARGET: "cross_small.svg",
	CursorState.MODIFY: "cursor_cogs.svg",
}

var _target: CanvasItem
var _state := CursorState.DEFAULT
var _position_tween: Tween
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	_previous_mouse_mode = _get_mouse_mode()
	_set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_priority(100)
	set_cursor_state(_state)


func _exit_tree() -> void:
	_set_mouse_mode(_previous_mouse_mode)


func _get_mouse_mode() -> Input.MouseMode:
	return Input.mouse_mode


func _set_mouse_mode(mode: Input.MouseMode) -> void:
	Input.mouse_mode = mode


func _process(_delta: float) -> void:
	update_position_for_behavior(InputManager.get_cursor_behavior(), get_viewport().get_mouse_position())


func set_focus_target(control: Control, state: CursorState = CursorState.DEFAULT) -> void:
	_target = control
	set_cursor_state(state)


func set_world_target(canvas_item: CanvasItem, state: CursorState = CursorState.TARGET) -> void:
	_target = canvas_item
	set_cursor_state(state)


func clear_target() -> void:
	_target = null
	hide()


func set_cursor_state(state: CursorState) -> void:
	_state = state
	texture = load("res://assets/graphics/glyphs/cursors/outline/%s" % STATE_FILES[state]) as Texture2D


func update_position_for_behavior(behavior: InputManager.CursorBehavior, mouse_position: Vector2, immediate := false) -> void:
	if behavior == InputManager.CursorBehavior.FREE:
		_move_to(mouse_position, true)
		show()
		return
	if not _is_valid_target():
		clear_target()
		return
	var destination := _target_position()
	_move_to(destination, immediate)
	if mouse_position.distance_to(destination) > InputManager.WARP_POSITION_TOLERANCE:
		InputManager.expect_mouse_warp(destination)
		_warp_mouse(destination)
	show()


func _warp_mouse(position: Vector2) -> void:
	Input.warp_mouse(position)


func _is_valid_target() -> bool:
	if not is_instance_valid(_target) or not _target.is_inside_tree() or not _target.is_visible_in_tree():
		return false
	return not (_target is BaseButton and (_target as BaseButton).disabled)


func _target_position() -> Vector2:
	if _target is Control:
		var control := _target as Control
		var anchor: Vector2 = control.get_meta("cursor_anchor", control.size * 0.5)
		return control.get_global_transform_with_canvas() * anchor
	return _target.get_global_transform_with_canvas().origin


func _move_to(destination: Vector2, immediate: bool) -> void:
	if is_instance_valid(_position_tween):
		_position_tween.kill()
	if immediate or not is_inside_tree():
		position = destination
		return
	_position_tween = create_tween()
	_position_tween.tween_property(self, "position", destination, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
