extends RefCounted
class_name EnemyHUDLayout


static func resolve(
	desired_rects: Array[Rect2],
	safe_rect: Rect2,
	gap := 6.0,
) -> Array[Rect2]:
	if desired_rects.is_empty():
		return []
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0 or gap < 0.0:
		return _fail()

	var clamped: Array[Rect2] = []
	for desired: Rect2 in desired_rects:
		if desired.size.x <= 0.0 or desired.size.y <= 0.0 \
			or desired.size.x > safe_rect.size.x \
			or desired.size.y > safe_rect.size.y:
			return _fail()
		clamped.append(_clamp_rect(desired, safe_rect))

	var processing_order: Array[int] = []
	for index in clamped.size():
		processing_order.append(index)
	processing_order.sort_custom(func(left: int, right: int) -> bool:
		var left_center := clamped[left].get_center()
		var right_center := clamped[right].get_center()
		if left_center.y != right_center.y:
			return left_center.y < right_center.y
		if left_center.x != right_center.x:
			return left_center.x < right_center.x
		return left < right
	)

	var resolved: Array[Rect2] = clamped.duplicate()
	var processed_indices: Array[int] = []
	for index: int in processing_order:
		var current := resolved[index]
		var shifted := true
		while shifted:
			shifted = false
			for prior_index: int in processed_indices:
				var prior := resolved[prior_index]
				if current.intersects(prior):
					current.position.y = prior.position.y - current.size.y - gap
					shifted = true
					break
		resolved[index] = current
		processed_indices.append(index)

	var top := INF
	for rect: Rect2 in resolved:
		top = minf(top, rect.position.y)
	if top < safe_rect.position.y:
		var translation := safe_rect.position.y - top
		for index in resolved.size():
			resolved[index].position.y += translation

	for index in resolved.size():
		resolved[index] = _clamp_rect(resolved[index], safe_rect)

	if not _is_valid_resolution(resolved, safe_rect):
		return _fail()
	return resolved


static func _clamp_rect(rect: Rect2, safe_rect: Rect2) -> Rect2:
	var max_position := safe_rect.end - rect.size
	return Rect2(
		Vector2(
			clampf(rect.position.x, safe_rect.position.x, max_position.x),
			clampf(rect.position.y, safe_rect.position.y, max_position.y),
		),
		rect.size,
	)


static func _is_valid_resolution(rects: Array[Rect2], safe_rect: Rect2) -> bool:
	for index in rects.size():
		var rect := rects[index]
		if not safe_rect.encloses(rect):
			return false
		for prior_index in index:
			if rect.intersects(rects[prior_index]):
				return false
	return true


static func _fail() -> Array[Rect2]:
	push_error("EnemyHUDLayout cannot fit HUD rectangles inside the safe area.")
	return []
