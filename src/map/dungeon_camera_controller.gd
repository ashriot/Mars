class_name DungeonCameraController
extends Node

const MIN_ZOOM := 0.001

enum FocusMode { PARTY, SCANNER }

var pan_speed := 600.0
var scanner_dead_zone_ratio := Vector2(0.6, 0.6)
var scanner_follow_response := 8.0
var focus_mode := FocusMode.PARTY

var _camera: Camera2D
var _background: Sprite2D
var _parallax: Parallax2D


func configure(
	camera_node: Camera2D,
	background_node: Sprite2D,
	parallax_node: Parallax2D,
) -> void:
	_camera = camera_node
	_background = background_node
	_parallax = parallax_node


func set_focus_mode(mode: FocusMode) -> void:
	focus_mode = mode


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
	var desired := desired_scanner_position(
		scanner_position, _camera.position, viewport_size, _camera.zoom
	)
	var weight := 1.0 - exp(-scanner_follow_response * maxf(delta, 0.0))
	_camera.position = clamp_position(
		_camera.position.lerp(desired, weight), _camera.zoom, viewport_size
	)
	return _camera.position


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
	_camera.position = clamp_position(target, _camera.zoom, viewport_size)
	return _camera.position


func recenter(party_position: Vector2, viewport_size: Vector2) -> Vector2:
	_camera.position = clamp_position(party_position, _camera.zoom, viewport_size)
	return _camera.position
