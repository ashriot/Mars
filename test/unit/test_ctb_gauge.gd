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
