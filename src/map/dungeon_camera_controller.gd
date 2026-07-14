class_name DungeonCameraController
extends Node

const MIN_ZOOM := 0.001
const ZOOM_TWEEN_DURATION := 0.3

enum FocusMode { PARTY, SCANNER }

var pan_speed := 600.0
var scanner_dead_zone_ratio := Vector2(0.6, 0.6)
var scanner_follow_response := 8.0
var focus_mode := FocusMode.PARTY
var min_zoom := 0.5
var max_zoom := 1.5
var smooth_speed := 0.3

var _camera: Camera2D
var _background: Sprite2D
var _parallax: Parallax2D
var _zoom_tween: Tween
var _position_tween: Tween
var _zoom_position_takeover := false


func configure(
	camera_node: Camera2D,
	background_node: Sprite2D,
	parallax_node: Parallax2D,
) -> void:
	_camera = camera_node
	_background = background_node
	_parallax = parallax_node


func set_focus_mode(mode: FocusMode) -> void:
	if focus_mode == FocusMode.PARTY and mode == FocusMode.SCANNER:
		_cancel_position_motion()
		_enable_zoom_position_takeover()
	focus_mode = mode


func cover_zoom(viewport_size: Vector2) -> Vector2:
	var background_size := _background.texture.get_size() * _background.scale
	var zoom_value := maxf(
		viewport_size.x / background_size.x,
		viewport_size.y / background_size.y,
	)
	return Vector2.ONE * zoom_value * 1.02


func hybrid_position(
	party_position: Vector2,
	at_zoom: Vector2,
	viewport_size: Vector2,
) -> Vector2:
	var limit_zoom := cover_zoom(viewport_size).x
	var influence := clampf(remap(at_zoom.x, limit_zoom, 1.0, 0.0, 1.0), 0.0, 1.0)
	return Vector2.ZERO.lerp(party_position, influence)


func move_to_party(
	party_position: Vector2,
	force_center: bool,
	viewport_size: Vector2,
) -> void:
	cancel_motion()
	set_focus_mode(FocusMode.PARTY)
	var target := hybrid_position(party_position, _camera.zoom, viewport_size)
	if force_center:
		_camera.position = target
		return
	_position_tween = create_tween()
	_position_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_position_tween.tween_property(_camera, "position", target, smooth_speed)


func zoom_by(
	step: float,
	party_position: Vector2,
	scanner_position: Vector2,
	viewport_size: Vector2,
) -> Vector2:
	cancel_motion()
	_zoom_position_takeover = false
	var minimum_allowed := minf(maxf(min_zoom, cover_zoom(viewport_size).x), max_zoom)
	var next_value := clampf(_camera.zoom.x + step, minimum_allowed, max_zoom)
	var final_zoom := Vector2.ONE * next_value
	if focus_mode == FocusMode.SCANNER:
		_camera.position = clamp_position(
			desired_scanner_position(scanner_position, _camera.position, viewport_size, final_zoom),
			final_zoom,
			viewport_size,
		)
	if focus_mode == FocusMode.PARTY:
		_position_tween = create_tween()
		_position_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_position_tween.tween_property(
			_camera,
			"position",
			hybrid_position(party_position, final_zoom, viewport_size),
			ZOOM_TWEEN_DURATION,
		)
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_method(
		_apply_zoom_and_clamp.bind(viewport_size),
		_camera.zoom,
		final_zoom,
		ZOOM_TWEEN_DURATION,
	)
	return final_zoom


func cancel_motion() -> void:
	_cancel_zoom_motion()
	_cancel_position_motion()


func has_active_motion() -> bool:
	return (
		(_zoom_tween != null and _zoom_tween.is_running())
		or (_position_tween != null and _position_tween.is_running())
	)


func _cancel_zoom_motion() -> void:
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_tween.kill()
	_zoom_tween = null
	_zoom_position_takeover = false


func _cancel_position_motion() -> void:
	if _position_tween and _position_tween.is_running():
		_position_tween.kill()
	_position_tween = null


func _apply_zoom_and_clamp(zoom_value: Vector2, viewport_size: Vector2) -> void:
	_camera.zoom = zoom_value
	if _zoom_position_takeover:
		_camera.position = clamp_position(_camera.position, zoom_value, viewport_size)


func desired_scanner_position(
	scanner_position: Vector2,
	camera_position: Vector2,
	viewport_size: Vector2,
	zoom_level: Vector2,
) -> Vector2:
	var safe_zoom := Vector2(
		maxf(absf(zoom_level.x), MIN_ZOOM),
		maxf(absf(zoom_level.y), MIN_ZOOM),
	)
	var half_dead_world := viewport_size * scanner_dead_zone_ratio * 0.5 / safe_zoom
	var offset := scanner_position - camera_position
	var target := camera_position
	if offset.x < -half_dead_world.x:
		target.x = scanner_position.x + half_dead_world.x
	elif offset.x > half_dead_world.x:
		target.x = scanner_position.x - half_dead_world.x
	if offset.y < -half_dead_world.y:
		target.y = scanner_position.y + half_dead_world.y
	elif offset.y > half_dead_world.y:
		target.y = scanner_position.y - half_dead_world.y
	return target


func follow_scanner(scanner_position: Vector2, delta: float, viewport_size: Vector2) -> Vector2:
	if focus_mode != FocusMode.SCANNER:
		return _camera.position
	_enable_zoom_position_takeover()
	var desired := desired_scanner_position(
		scanner_position, _camera.position, viewport_size, _camera.zoom
	)
	var weight := 1.0 - exp(-scanner_follow_response * maxf(delta, 0.0))
	_camera.position = clamp_position(
		_camera.position.lerp(desired, weight), _camera.zoom, viewport_size
	)
	return _camera.position


func scanner_is_inside_safe_area(scanner_position: Vector2, viewport_size: Vector2) -> bool:
	return desired_scanner_position(
		scanner_position,
		_camera.position,
		viewport_size,
		_camera.zoom,
	).is_equal_approx(_camera.position)


func clamp_position(
	target_position: Vector2,
	zoom_level: Vector2,
	viewport_size: Vector2,
) -> Vector2:
	var safe_zoom := Vector2(
		maxf(absf(zoom_level.x), MIN_ZOOM),
		maxf(absf(zoom_level.y), MIN_ZOOM),
	)
	var visible_world_size := viewport_size / safe_zoom
	var background_size := _background.texture.get_size() * _background.scale
	var parallax_scale := Vector2.ONE
	if _parallax and _parallax.scroll_scale != Vector2.ZERO:
		parallax_scale = _parallax.scroll_scale
	var half_background := background_size / parallax_scale / 3.0
	var half_view := visible_world_size / 3.0
	var minimum := -half_background + half_view
	var maximum := half_background - half_view
	if minimum.x > maximum.x:
		minimum.x = 0.0
		maximum.x = 0.0
	if minimum.y > maximum.y:
		minimum.y = 0.0
		maximum.y = 0.0
	return Vector2(
		clampf(target_position.x, minimum.x, maximum.x),
		clampf(target_position.y, minimum.y, maximum.y),
	)


func pan(direction: Vector2, delta: float, viewport_size: Vector2) -> Vector2:
	if direction.is_zero_approx() or delta <= 0.0:
		return _camera.position
	var target := _camera.position + direction.normalized() * pan_speed * delta * _camera.zoom.x
	return apply_manual_position_candidate(target, viewport_size)


func recenter(party_position: Vector2, viewport_size: Vector2) -> Vector2:
	return apply_manual_position_candidate(party_position, viewport_size)


func apply_manual_position_candidate(candidate: Vector2, viewport_size: Vector2) -> Vector2:
	_cancel_position_motion()
	_enable_zoom_position_takeover()
	_camera.position = clamp_position(candidate, _camera.zoom, viewport_size)
	return _camera.position


func _enable_zoom_position_takeover() -> void:
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_position_takeover = true
