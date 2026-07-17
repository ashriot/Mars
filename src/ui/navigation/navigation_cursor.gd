extends TextureRect
class_name NavigationCursor

signal hub_target_invalidated

const POINTER_TEXTURE := preload("res://assets/graphics/glyphs/cursors/outline/pointer_c.svg")
const HUB_MOVE_DURATION := 0.07
const HUB_ANCHOR_OFFSET := Vector2(6, 6)
const VIEWPORT_MARGIN := 4.0
const READABLE_CENTER_SCALE := 0.5

enum PointerOwner { NONE, HUB, EXTERNAL }

var _owner := PointerOwner.NONE
var _hub_target: WeakRef
var _move_tween: Tween

func _ready() -> void:
	texture = POINTER_TEXTURE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_at_screen_position(screen_position: Vector2) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	_hub_target = null
	_owner = PointerOwner.EXTERNAL
	position = screen_position
	show()


func hide_pointer() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	_hub_target = null
	_owner = PointerOwner.NONE
	hide()


func track_hub_target(target: Control, animate: bool = true) -> void:
	if not _valid_hub_target(target):
		clear_hub_target()
		return
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_owner = PointerOwner.HUB
	_hub_target = weakref(target)
	var start := position
	if not visible or not animate:
		position = _hub_position(target)
		show()
		return
	show()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tween.tween_method(func(weight: float) -> void:
		var live_target := _hub_target.get_ref() as Control if _hub_target else null
		if _valid_hub_target(live_target):
			position = start.lerp(_hub_position(live_target), weight)
	, 0.0, 1.0, HUB_MOVE_DURATION)


func clear_hub_target() -> void:
	if _owner != PointerOwner.HUB:
		return
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	_hub_target = null
	_owner = PointerOwner.NONE
	hide()


func is_tracking_hub_target() -> bool:
	return _owner == PointerOwner.HUB and _hub_target != null


func _process(_delta: float) -> void:
	if _owner != PointerOwner.HUB:
		return
	var target := _hub_target.get_ref() as Control if _hub_target else null
	if not _valid_hub_target(target):
		clear_hub_target()
		hub_target_invalidated.emit()
		return
	if _move_tween and _move_tween.is_running():
		return
	position = _hub_position(target)


func _hub_position(target: Control) -> Vector2:
	var target_rect := target.get_global_rect()
	var requested := target_rect.end + HUB_ANCHOR_OFFSET
	var viewport_size := Vector2(get_viewport_rect().size)
	var cursor_size := _effective_cursor_size()
	var preferred := _clamp_to_viewport(requested, cursor_size, viewport_size)
	var readable_center := _readable_center_rect(target_rect)
	if not Rect2(preferred, cursor_size).intersects(readable_center, true):
		return preferred

	var left := target_rect.position.x - cursor_size.x - HUB_ANCHOR_OFFSET.x
	var above := target_rect.position.y - cursor_size.y - HUB_ANCHOR_OFFSET.y
	var candidates: Array[Vector2] = [
		Vector2(left, requested.y),
		Vector2(requested.x, above),
		Vector2(left, above),
		Vector2(readable_center.position.x - cursor_size.x - HUB_ANCHOR_OFFSET.x, preferred.y),
		Vector2(readable_center.end.x + HUB_ANCHOR_OFFSET.x, preferred.y),
		Vector2(preferred.x, readable_center.position.y - cursor_size.y - HUB_ANCHOR_OFFSET.y),
		Vector2(preferred.x, readable_center.end.y + HUB_ANCHOR_OFFSET.y),
	]
	var best := preferred
	var best_distance := INF
	for raw_candidate in candidates:
		var candidate := _clamp_to_viewport(raw_candidate, cursor_size, viewport_size)
		if Rect2(candidate, cursor_size).intersects(readable_center, true):
			continue
		var distance := candidate.distance_squared_to(preferred)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _effective_cursor_size() -> Vector2:
	var result := size
	if is_instance_valid(texture):
		var texture_size := texture.get_size()
		result.x = maxf(result.x, texture_size.x)
		result.y = maxf(result.y, texture_size.y)
	return result


func _clamp_to_viewport(requested: Vector2, cursor_size: Vector2, viewport_size: Vector2) -> Vector2:
	return Vector2(
		clampf(requested.x, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.x - cursor_size.x - VIEWPORT_MARGIN)),
		clampf(requested.y, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.y - cursor_size.y - VIEWPORT_MARGIN)),
	)


func _readable_center_rect(target_rect: Rect2) -> Rect2:
	var readable_size := target_rect.size * READABLE_CENTER_SCALE
	return Rect2(target_rect.get_center() - readable_size * 0.5, readable_size)


func _valid_hub_target(target: Control) -> bool:
	return (
		is_instance_valid(target)
		and target.is_inside_tree()
		and target.is_visible_in_tree()
		and target.focus_mode != Control.FOCUS_NONE
		and not (target is BaseButton and target.disabled)
	)
