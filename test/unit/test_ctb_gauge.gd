extends GutTest


func test_readiness_fill_uses_fixed_inverse_zero_to_eighty_tick_scale() -> void:
	assert_eq(CTBGauge.readiness_fill(-10), 1.0)
	assert_eq(CTBGauge.readiness_fill(0), 1.0)
	assert_eq(CTBGauge.readiness_fill(20), 0.75)
	assert_eq(CTBGauge.readiness_fill(40), 0.5)
	assert_eq(CTBGauge.readiness_fill(60), 0.25)
	assert_eq(CTBGauge.readiness_fill(80), 0.0)
	assert_eq(CTBGauge.readiness_fill(100), 0.0)


func test_readiness_gauge_uses_one_bright_faction_color() -> void:
	assert_eq(CTBGauge.faction_color(CTBGauge.Faction.HERO), Color("56e5ff"))
	assert_eq(CTBGauge.faction_color(CTBGauge.Faction.ENEMY), Color("ff5bc8"))


func test_rounded_path_starts_top_center_and_runs_clockwise_by_quarters() -> void:
	var rect := Rect2(Vector2(3, 3), Vector2(66, 66))
	var path := CTBGauge.rounded_rect_path(rect, 10.0)
	assert_eq(path[0], Vector2(36, 3))
	assert_eq(path[-1], path[0])

	var quarter := CTBGauge.partial_polyline(path, 0.25)
	assert_almost_eq(quarter[-1].x, 69.0, 0.01)
	assert_almost_eq(quarter[-1].y, 36.0, 0.01)
	var half := CTBGauge.partial_polyline(path, 0.5)
	assert_almost_eq(half[-1].x, 36.0, 0.01)
	assert_almost_eq(half[-1].y, 69.0, 0.01)
	var three_quarters := CTBGauge.partial_polyline(path, 0.75)
	assert_almost_eq(three_quarters[-1].x, 3.0, 0.01)
	assert_almost_eq(three_quarters[-1].y, 36.0, 0.01)


func test_partial_perimeter_has_exact_end_interpolation() -> void:
	var square := PackedVector2Array([
		Vector2.ZERO, Vector2(10, 0), Vector2(10, 10),
		Vector2(0, 10), Vector2.ZERO,
	])
	var half := CTBGauge.partial_polyline(square, 0.5)
	assert_eq(half[-1], Vector2(10, 10))


func test_partial_perimeter_skips_zero_length_duplicate_segments() -> void:
	var duplicate_run := PackedVector2Array([
		Vector2(10, 10), Vector2(10, 10), Vector2(10, 10),
	])
	var half := CTBGauge.partial_polyline(duplicate_run, 0.5)

	assert_true(half[-1].is_finite())
	assert_eq(half[-1], Vector2(10, 10))


func test_gauge_interpolates_ticks_without_mutating_target() -> void:
	var gauge := CTBGauge.new()
	add_child_autofree(gauge)
	gauge.configure(20, CTBGauge.Faction.HERO, false, false)
	gauge.configure(40, CTBGauge.Faction.HERO, false, true)

	assert_eq(gauge.displayed_ticks, 20.0)
	assert_eq(gauge._target_ticks, 40.0)
	gauge._advance_animation(CTBGauge.ANIMATION_DURATION * 0.5)
	assert_eq(gauge.displayed_ticks, 30.0)
	assert_eq(CTBGauge.readiness_fill(gauge.displayed_ticks), 0.625)
	gauge._advance_animation(CTBGauge.ANIMATION_DURATION * 0.5)
	assert_eq(gauge.displayed_ticks, 40.0)
	assert_false(gauge._is_animating)


func test_new_target_replaces_in_flight_gauge_animation() -> void:
	var gauge := CTBGauge.new()
	add_child_autofree(gauge)
	gauge.configure(20, CTBGauge.Faction.ENEMY, false, false)
	gauge.configure(60, CTBGauge.Faction.ENEMY, false, true)
	gauge._advance_animation(CTBGauge.ANIMATION_DURATION * 0.5)
	gauge.configure(10, CTBGauge.Faction.ENEMY, false, true)
	assert_eq(gauge._start_ticks, 40.0)
	gauge._advance_animation(CTBGauge.ANIMATION_DURATION)
	assert_eq(gauge.displayed_ticks, 10.0)


func test_cancel_animation_stops_in_flight_processing() -> void:
	var gauge := CTBGauge.new()
	add_child_autofree(gauge)
	gauge.configure(20, CTBGauge.Faction.HERO, false, false)
	gauge.configure(40, CTBGauge.Faction.HERO, false, true)
	assert_true(gauge._is_animating)

	gauge.cancel_animation()

	assert_false(gauge._is_animating)
	assert_false(gauge.is_processing())
