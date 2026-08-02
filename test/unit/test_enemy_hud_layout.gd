extends GutTest


const SAFE_RECT := Rect2(0, 0, 1280, 800)


func test_clamps_each_safe_area_edge_exactly() -> void:
	var desired: Array[Rect2] = [
		Rect2(-20, 100, 100, 50),
		Rect2(1200, 200, 100, 50),
		Rect2(300, -10, 100, 50),
		Rect2(500, 770, 100, 50),
	]

	var resolved := EnemyHUDLayout.resolve(desired, SAFE_RECT)

	assert_eq(resolved, [
		Rect2(0, 100, 100, 50),
		Rect2(1180, 200, 100, 50),
		Rect2(300, 0, 100, 50),
		Rect2(500, 750, 100, 50),
	])


func test_five_overlapping_huds_resolve_upward_in_stable_input_order() -> void:
	var desired: Array[Rect2] = []
	for _index in 5:
		desired.append(Rect2(500, 300, 120, 48))

	var resolved := EnemyHUDLayout.resolve(desired, SAFE_RECT)

	assert_eq(resolved, [
		Rect2(500, 300, 120, 48),
		Rect2(500, 246, 120, 48),
		Rect2(500, 192, 120, 48),
		Rect2(500, 138, 120, 48),
		Rect2(500, 84, 120, 48),
	])
	assert_eq(EnemyHUDLayout.resolve(desired, SAFE_RECT), resolved)


func test_top_crossing_translates_complete_resolved_group_down() -> void:
	var desired: Array[Rect2] = [
		Rect2(400, 20, 100, 40),
		Rect2(400, 20, 100, 40),
		Rect2(400, 20, 100, 40),
	]

	var resolved := EnemyHUDLayout.resolve(desired, SAFE_RECT)

	assert_eq(resolved, [
		Rect2(400, 92, 100, 40),
		Rect2(400, 46, 100, 40),
		Rect2(400, 0, 100, 40),
	])


func test_non_overlapping_rectangles_remain_unchanged_and_restore_original_order() -> void:
	var desired: Array[Rect2] = [
		Rect2(800, 500, 100, 40),
		Rect2(100, 100, 100, 40),
		Rect2(400, 300, 100, 40),
	]

	assert_eq(EnemyHUDLayout.resolve(desired, SAFE_RECT), desired)


func test_upward_shift_rechecks_earlier_horizontal_collision() -> void:
	var desired: Array[Rect2] = [
		Rect2(0, 100, 100, 50),
		Rect2(100, 200, 100, 50),
		Rect2(50, 210, 100, 50),
	]

	assert_eq(EnemyHUDLayout.resolve(desired, SAFE_RECT), [
		Rect2(0, 100, 100, 50),
		Rect2(100, 200, 100, 50),
		Rect2(50, 44, 100, 50),
	])


func test_impossible_stack_returns_empty_and_reports_one_error() -> void:
	var desired: Array[Rect2] = []
	for _index in 5:
		desired.append(Rect2(500, 300, 120, 160))

	var resolved := EnemyHUDLayout.resolve(desired, SAFE_RECT)

	assert_true(resolved.is_empty())
	assert_push_error("EnemyHUDLayout cannot fit HUD rectangles inside the safe area.")
