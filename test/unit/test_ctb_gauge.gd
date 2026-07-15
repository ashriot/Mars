extends GutTest


func test_fixed_twenty_tick_bands_and_saturation() -> void:
	assert_eq(CTBGauge.band_fills(0), [0.0, 0.0, 0.0])
	assert_eq(CTBGauge.band_fills(10), [0.5, 0.0, 0.0])
	assert_eq(CTBGauge.band_fills(20), [1.0, 0.0, 0.0])
	assert_eq(CTBGauge.band_fills(31), [1.0, 0.55, 0.0])
	assert_eq(CTBGauge.band_fills(55), [1.0, 1.0, 0.75])
	assert_eq(CTBGauge.band_fills(70), [1.0, 1.0, 1.0])


func test_quarter_recovery_steps_map_to_half_band_steps() -> void:
	assert_eq(CTBGauge.band_fills(30), [1.0, 0.5, 0.0]) # 75% CT
	assert_eq(CTBGauge.band_fills(40), [1.0, 1.0, 0.0]) # 100% CT
	assert_eq(CTBGauge.band_fills(50), [1.0, 1.0, 0.5]) # 125% CT
	assert_eq(CTBGauge.band_fills(60), [1.0, 1.0, 1.0]) # 150% CT


func test_partial_perimeter_has_exact_end_interpolation() -> void:
	var square := PackedVector2Array([
		Vector2.ZERO, Vector2(10, 0), Vector2(10, 10),
		Vector2(0, 10), Vector2.ZERO,
	])
	var half := CTBGauge.partial_polyline(square, 0.5)
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
	assert_eq(CTBGauge.band_fills(gauge.displayed_ticks), [1.0, 0.5, 0.0])
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
