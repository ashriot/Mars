extends RefCounted
class_name SkillTreeNavigation


static func find_directional_candidate(current_id: String, direction: Vector2, positions: Dictionary) -> String:
	if current_id.is_empty() or not positions.has(current_id) or direction.is_zero_approx():
		return ""
	var origin: Vector2 = positions[current_id]
	var normalized_direction := direction.normalized()
	var candidates: Array[Dictionary] = []
	for candidate_id: String in positions:
		if candidate_id == current_id:
			continue
		var offset: Vector2 = positions[candidate_id] - origin
		if offset.is_zero_approx():
			continue
		var dot := offset.normalized().dot(normalized_direction)
		if dot <= 0.0:
			continue
		candidates.append({"id": candidate_id, "dot": dot, "distance": offset.length_squared()})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.dot != b.dot:
			return a.dot > b.dot
		if a.distance != b.distance:
			return a.distance < b.distance
		return a.id < b.id
	)
	return candidates[0].id if not candidates.is_empty() else ""
