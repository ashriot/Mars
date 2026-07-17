extends TextureRect
class_name NavigationCursor

signal hub_target_invalidated

const POINTER_TEXTURE := preload("res://assets/graphics/glyphs/cursors/outline/pointer_c.svg")
const HUB_POINTER_TEXTURE := preload("res://assets/graphics/glyphs/cursors/outline/hand_point_e.svg")
const HUB_MOVE_DURATION := 0.07
const HUB_RENDER_SCALE := Vector2(2, 2)
const HUB_REST_OVERLAP := 8.0
const HUB_HEADER_TIP_Y := 28.0
const HUB_BREATH_DISTANCE := 6.0
const HUB_BREATH_AWAY_DURATION := 0.65
const HUB_BREATH_RETURN_DURATION := 0.16
const VIEWPORT_MARGIN := 4.0
const READABLE_CENTER_SCALE := 0.5

enum PointerOwner { NONE, HUB, EXTERNAL }

var _owner := PointerOwner.NONE
var _hub_target: WeakRef
var _move_tween: Tween
var _breath_tween: Tween
var _anchor_position := Vector2.ZERO
var _breath_weight := 0.0

func _ready() -> void:
	texture = POINTER_TEXTURE
	scale = Vector2.ONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_at_screen_position(screen_position: Vector2) -> void:
	_stop_breathing()
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	_hub_target = null
	_owner = PointerOwner.EXTERNAL
	texture = POINTER_TEXTURE
	scale = Vector2.ONE
	_anchor_position = screen_position
	position = screen_position
	show()


func hide_pointer() -> void:
	_stop_breathing()
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	_hub_target = null
	_owner = PointerOwner.NONE
	scale = Vector2.ONE
	hide()


func track_hub_target(target: Control, animate: bool = true) -> void:
	if not _valid_hub_target(target):
		clear_hub_target()
		return
	_stop_breathing()
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_owner = PointerOwner.HUB
	_hub_target = weakref(target)
	texture = HUB_POINTER_TEXTURE
	scale = HUB_RENDER_SCALE
	var start := position
	if not visible or not animate:
		_anchor_position = _hub_position(target)
		_apply_visual_position()
		show()
		_start_breathing()
		return
	show()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tween.tween_method(func(weight: float) -> void:
		var live_target := _hub_target.get_ref() as Control if _hub_target else null
		if _valid_hub_target(live_target):
			_anchor_position = start.lerp(_hub_position(live_target), weight)
			_apply_visual_position()
	, 0.0, 1.0, HUB_MOVE_DURATION)
	_move_tween.tween_callback(_start_breathing)


func clear_hub_target() -> void:
	if _owner != PointerOwner.HUB:
		return
	_stop_breathing()
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
	_anchor_position = _hub_position(target)
	_apply_visual_position()


func _hub_position(target: Control) -> Vector2:
	var target_rect := target.get_global_rect()
	var viewport_size := Vector2(get_viewport_rect().size)
	var cursor_size := _effective_cursor_size()
	var tip_y := minf(target_rect.size.y * 0.5, HUB_HEADER_TIP_Y)
	var requested := Vector2(
		target_rect.position.x - cursor_size.x + HUB_REST_OVERLAP,
		target_rect.position.y + tip_y - HUB_HEADER_TIP_Y,
	)
	var preferred := _clamp_hub_anchor(requested, cursor_size, viewport_size)
	var readable_center := _readable_center_rect(target_rect)
	if not Rect2(preferred, cursor_size).intersects(readable_center, false):
		return preferred

	var candidates: Array[Vector2] = [
		Vector2(requested.x, readable_center.position.y - cursor_size.y),
		Vector2(requested.x, readable_center.end.y),
		Vector2(target_rect.end.x - HUB_REST_OVERLAP, requested.y),
	]
	var best := preferred
	var best_distance := INF
	for raw_candidate in candidates:
		var candidate := _clamp_hub_anchor(raw_candidate, cursor_size, viewport_size)
		if Rect2(candidate, cursor_size).intersects(readable_center, false):
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
	return Vector2(result.x * absf(scale.x), result.y * absf(scale.y))


func _start_breathing() -> void:
	if _owner != PointerOwner.HUB or not _valid_hub_target(_hub_target.get_ref() as Control if _hub_target else null):
		return
	_stop_breathing()
	_breath_tween = create_tween().set_loops()
	_breath_tween.tween_method(_set_breath_weight, 0.0, 1.0, HUB_BREATH_AWAY_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_method(_set_breath_weight, 1.0, 0.0, HUB_BREATH_RETURN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _stop_breathing() -> void:
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null
	_breath_weight = 0.0
	if _owner == PointerOwner.HUB:
		position = _anchor_position


func _set_breath_weight(weight: float) -> void:
	_breath_weight = weight
	_apply_visual_position()


func _apply_visual_position() -> void:
	var target := _hub_target.get_ref() as Control if _hub_target else null
	if _owner != PointerOwner.HUB or not _valid_hub_target(target):
		position = _anchor_position
		return
	var away := Vector2.LEFT * HUB_BREATH_DISTANCE * _breath_weight
	position = _clamp_to_viewport(
		_anchor_position + away,
		_effective_cursor_size(),
		Vector2(get_viewport_rect().size),
	)


func _clamp_hub_anchor(requested: Vector2, cursor_size: Vector2, viewport_size: Vector2) -> Vector2:
	return Vector2(
		clampf(
			requested.x,
			VIEWPORT_MARGIN + HUB_BREATH_DISTANCE,
			maxf(VIEWPORT_MARGIN + HUB_BREATH_DISTANCE, viewport_size.x - cursor_size.x - VIEWPORT_MARGIN),
		),
		clampf(requested.y, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.y - cursor_size.y - VIEWPORT_MARGIN)),
	)


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
