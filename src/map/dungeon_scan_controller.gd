class_name DungeonScanController
extends RefCounted

var cursor_speed := 600.0
var active := false
var pointer_position := Vector2.ZERO
var selected_node: MapNode


func begin(origin_position: Vector2, viewport_size: Vector2, origin: MapNode) -> void:
	active = true
	pointer_position = _clamp_to_viewport(origin_position, viewport_size)
	selected_node = origin


func stop() -> void:
	active = false
	selected_node = null


func set_selected(node: MapNode) -> MapNode:
	selected_node = node
	return selected_node


func sync_pointer(position: Vector2, viewport_size: Vector2) -> Vector2:
	pointer_position = _clamp_to_viewport(position, viewport_size)
	return pointer_position


func move_pointer(direction: Vector2, delta: float, viewport_size: Vector2) -> Vector2:
	if not active or direction.is_zero_approx() or delta <= 0.0:
		return pointer_position
	var limited_direction := direction.limit_length(1.0)
	pointer_position = _clamp_to_viewport(
		pointer_position + limited_direction * cursor_speed * delta,
		viewport_size,
	)
	return pointer_position


func _clamp_to_viewport(position: Vector2, viewport_size: Vector2) -> Vector2:
	var maximum := Vector2(
		maxf(viewport_size.x - 1.0, 0.0),
		maxf(viewport_size.y - 1.0, 0.0),
	)
	return position.clamp(Vector2.ZERO, maximum)
