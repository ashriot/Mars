class_name DungeonNavigation
extends RefCounted


static func closest_by_angle(origin: Vector2, direction: Vector2, candidates: Array[MapNode]) -> MapNode:
	if direction.is_zero_approx():
		return null

	var normalized_direction := direction.normalized()
	var best: MapNode = null
	var best_dot := -INF
	var best_distance := INF
	for candidate: MapNode in candidates:
		if candidate == null or not candidate.navigation_eligible:
			continue
		var offset := candidate.position - origin
		if offset.is_zero_approx():
			continue
		var alignment := offset.normalized().dot(normalized_direction)
		if alignment <= 0.0:
			continue
		var distance := offset.length_squared()
		if best == null or alignment > best_dot or (
			is_equal_approx(alignment, best_dot) and (
				distance < best_distance or (
					is_equal_approx(distance, best_distance) and _coordinates_before(candidate, best)
				)
			)
		):
			best = candidate
			best_dot = alignment
			best_distance = distance
	return best


static func _coordinates_before(a: MapNode, b: MapNode) -> bool:
	return a.grid_coords.x < b.grid_coords.x or (
		a.grid_coords.x == b.grid_coords.x and a.grid_coords.y < b.grid_coords.y
	)
