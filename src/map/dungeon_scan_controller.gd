class_name DungeonScanController
extends RefCounted

const REPEAT_DELAY := 0.32
const REPEAT_INTERVAL := 0.12
const DIRECTION_CHANGE_DOT := 0.99

var active := false
var selected_node: MapNode
var _last_direction := Vector2.ZERO
var _direction_hold_time := 0.0


func begin(origin: MapNode) -> void:
	active = true
	selected_node = origin
	_reset_repeat()


func stop() -> void:
	active = false
	selected_node = null
	_reset_repeat()


func set_selected(node: MapNode) -> MapNode:
	selected_node = node
	_reset_repeat()
	return selected_node


func process_direction(
	direction: Vector2,
	nodes: Array[MapNode],
	delta: float,
) -> MapNode:
	if not active or selected_node == null:
		return selected_node
	if direction.is_zero_approx():
		_reset_repeat()
		return selected_node
	var normalized := direction.normalized()
	var changed := (
		_last_direction.is_zero_approx()
		or normalized.dot(_last_direction.normalized()) < DIRECTION_CHANGE_DOT
	)
	if changed:
		_step(normalized, nodes)
		_direction_hold_time = 0.0
	else:
		_direction_hold_time += maxf(delta, 0.0)
		if _direction_hold_time >= REPEAT_DELAY:
			_step(normalized, nodes)
			_direction_hold_time = REPEAT_DELAY - REPEAT_INTERVAL
	_last_direction = normalized
	return selected_node


func _step(direction: Vector2, nodes: Array[MapNode]) -> void:
	var best: MapNode
	var best_alignment := -INF
	for candidate: MapNode in nodes:
		if candidate == null or candidate == selected_node:
			continue
		if _hex_distance(selected_node.grid_coords, candidate.grid_coords) != 1:
			continue
		var offset := candidate.position - selected_node.position
		if offset.is_zero_approx():
			continue
		var alignment := offset.normalized().dot(direction)
		if alignment <= 0.0:
			continue
		if best == null or alignment > best_alignment or (
			is_equal_approx(alignment, best_alignment) and _coordinates_before(candidate, best)
		):
			best = candidate
			best_alignment = alignment
	if best != null:
		selected_node = best


func _reset_repeat() -> void:
	_last_direction = Vector2.ZERO
	_direction_hold_time = 0.0


static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac := _offset_to_cube(a)
	var bc := _offset_to_cube(b)
	return maxi(abs(ac.x - bc.x), maxi(abs(ac.y - bc.y), abs(ac.z - bc.z)))


static func _offset_to_cube(hex: Vector2i) -> Vector3i:
	var q := hex.x - (hex.y + (hex.y & 1)) / 2
	var r := hex.y
	return Vector3i(q, r, -q - r)


static func _coordinates_before(a: MapNode, b: MapNode) -> bool:
	return a.grid_coords.x < b.grid_coords.x or (
		a.grid_coords.x == b.grid_coords.x and a.grid_coords.y < b.grid_coords.y
	)
