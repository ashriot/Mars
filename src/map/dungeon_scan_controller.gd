class_name DungeonScanController
extends RefCounted

const MIN_ZOOM := 0.001

var cursor_speed := 600.0
var dead_zone_ratio := Vector2(0.6, 0.6)
var active := false
var position := Vector2.ZERO
var selected_node: MapNode
var _bounds := Rect2()


func begin(origin: Vector2, bounds: Rect2) -> void:
	active = true
	_bounds = bounds
	set_position(origin)


func stop() -> void:
	active = false
	selected_node = null


func set_position(value: Vector2) -> Vector2:
	var end := _bounds.position + _bounds.size
	position = Vector2(
		clampf(value.x, _bounds.position.x, end.x),
		clampf(value.y, _bounds.position.y, end.y),
	)
	return position


func move(direction: Vector2, delta: float, zoom: Vector2) -> Vector2:
	if not active or direction.is_zero_approx() or delta <= 0.0:
		return position
	var limited := direction.limit_length(1.0)
	var safe_zoom := Vector2(
		maxf(absf(zoom.x), MIN_ZOOM),
		maxf(absf(zoom.y), MIN_ZOOM),
	)
	return set_position(position + limited * cursor_speed * delta / safe_zoom)


func select_nearest(nodes: Array[MapNode]) -> MapNode:
	var best: MapNode
	var best_distance := INF
	for node: MapNode in nodes:
		if node == null:
			continue
		var distance := position.distance_squared_to(node.position)
		if best == null or distance < best_distance or (
			distance == best_distance and _coordinates_before(node, best)
		):
			best = node
			best_distance = distance
	selected_node = best
	return best


func desired_camera_position(
	camera_position: Vector2,
	viewport_size: Vector2,
	zoom: Vector2,
) -> Vector2:
	var safe_zoom := Vector2(
		maxf(absf(zoom.x), MIN_ZOOM),
		maxf(absf(zoom.y), MIN_ZOOM),
	)
	var half_dead_world := viewport_size * dead_zone_ratio * 0.5 / safe_zoom
	var offset := position - camera_position
	var target := camera_position
	if offset.x < -half_dead_world.x:
		target.x = position.x + half_dead_world.x
	elif offset.x > half_dead_world.x:
		target.x = position.x - half_dead_world.x
	if offset.y < -half_dead_world.y:
		target.y = position.y + half_dead_world.y
	elif offset.y > half_dead_world.y:
		target.y = position.y - half_dead_world.y
	return target


static func bounds_for_nodes(nodes: Array[MapNode]) -> Rect2:
	if nodes.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var minimum := nodes[0].position
	var maximum := nodes[0].position
	for node: MapNode in nodes:
		minimum = minimum.min(node.position)
		maximum = maximum.max(node.position)
	return Rect2(minimum, maximum - minimum)


static func _coordinates_before(a: MapNode, b: MapNode) -> bool:
	return a.grid_coords.x < b.grid_coords.x or (
		a.grid_coords.x == b.grid_coords.x and a.grid_coords.y < b.grid_coords.y
	)
