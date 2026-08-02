extends Node3D
class_name BattleCameraRig

@export_range(0.0, 0.5, 0.001) var max_pitch_radians := Vector2(
	deg_to_rad(2.0), 0.0,
).x
@export_range(0.0, 0.5, 0.001) var max_yaw_radians := Vector2(
	deg_to_rad(3.0), 0.0,
).x
@export_range(0.0, 0.95, 0.01) var edge_dead_zone := 0.6
@export_range(0.0, 30.0, 0.1) var edge_ease_speed := 7.0
@export_range(0.0, 0.05, 0.0001) var idle_pitch_amplitude := deg_to_rad(0.12)
@export_range(0.0, 0.05, 0.0001) var idle_yaw_amplitude := deg_to_rad(0.18)
@export_range(0.0, 10.0, 0.1) var trauma_decay := 2.2
@export_range(0.0, 0.2, 0.001) var max_shake_pitch := deg_to_rad(1.2)
@export_range(0.0, 0.2, 0.001) var max_shake_yaw := deg_to_rad(1.8)

var shake_scale := 1.0
var trauma := 0.0
var edge_rotation_target := Vector2.ZERO
var edge_rotation := Vector2.ZERO

var _neutral_rotation := Vector3.ZERO
var _elapsed := 0.0
var _pointer_override := Vector2.ZERO
var _has_pointer_override := false


func _ready() -> void:
	_neutral_rotation = rotation


func edge_rotation_for(pointer_screen: Vector2, viewport_size: Vector2) -> Vector2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	var half_size := viewport_size * 0.5
	var normalized := Vector2(
		clampf((pointer_screen.x - half_size.x) / half_size.x, -1.0, 1.0),
		clampf((pointer_screen.y - half_size.y) / half_size.y, -1.0, 1.0),
	)
	return Vector2(
		_edge_amount(normalized.y) * max_pitch_radians,
		_edge_amount(normalized.x) * max_yaw_radians,
	)


func request_shake(intensity: float) -> void:
	var effective_intensity := clampf(intensity, 0.0, 1.0) \
		* clampf(shake_scale, 0.0, 1.0) \
		* CombatPresentationSettings.shake_intensity
	if is_zero_approx(effective_intensity):
		return
	trauma = clampf(maxf(trauma, effective_intensity), 0.0, 1.0)


func set_pointer_screen_position(position: Vector2) -> void:
	_pointer_override = position
	_has_pointer_override = true


func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if InputManager.get_active_mode() == InputManager.InputMode.KEYBOARD_MOUSE \
		and InputManager.get_presentation_mode() == InputManager.PresentationMode.POINTER:
		var viewport_size := get_viewport().get_visible_rect().size
		var pointer_screen := _pointer_override \
			if _has_pointer_override else get_viewport().get_mouse_position()
		edge_rotation_target = edge_rotation_for(pointer_screen, viewport_size)
	else:
		edge_rotation_target = Vector2.ZERO
	edge_rotation = edge_rotation.lerp(
		edge_rotation_target,
		1.0 - exp(-edge_ease_speed * maxf(delta, 0.0)),
	)
	var idle_rotation := Vector2(
		sin(_elapsed * 0.47) * idle_pitch_amplitude,
		sin(_elapsed * 0.31 + 1.7) * idle_yaw_amplitude,
	)
	var shake_rotation := _shake_rotation()
	rotation = _neutral_rotation + Vector3(
		edge_rotation.x + idle_rotation.x + shake_rotation.x,
		edge_rotation.y + idle_rotation.y + shake_rotation.y,
		0.0,
	)
	trauma = maxf(trauma - trauma_decay * maxf(delta, 0.0), 0.0)


func _edge_amount(value: float) -> float:
	var magnitude := absf(value)
	if magnitude <= edge_dead_zone:
		return 0.0
	return signf(value) * clampf(
		inverse_lerp(edge_dead_zone, 1.0, magnitude), 0.0, 1.0,
	)


func _shake_rotation() -> Vector2:
	if is_zero_approx(trauma):
		return Vector2.ZERO
	var strength := trauma * trauma
	return Vector2(
		sin(_elapsed * 83.0 + 0.4) * max_shake_pitch * strength,
		sin(_elapsed * 97.0 + 2.1) * max_shake_yaw * strength,
	)
