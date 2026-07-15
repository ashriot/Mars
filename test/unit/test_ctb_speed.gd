extends GutTest


func test_odd_and_even_medians_normalize_to_one_hundred() -> void:
	var odd_scale := CTBSpeed.scale_for([16, 18, 24])
	assert_eq(CTBSpeed.normalize(18, odd_scale), 100)
	var even_scale := CTBSpeed.scale_for([16, 18, 22, 24])
	assert_eq(CTBSpeed.normalize(20, even_scale), 100)


func test_common_scale_preserves_endgame_speed_ratio_with_integer_precision() -> void:
	var scale := CTBSpeed.scale_for([500, 650, 800])
	assert_eq(CTBSpeed.normalize(500, scale), 77)
	assert_eq(CTBSpeed.normalize(650, scale), 100)
	assert_eq(CTBSpeed.normalize(800, scale), 123)


func test_empty_nonpositive_and_head_start_boundaries_are_safe() -> void:
	assert_eq(CTBSpeed.scale_for([]), 1.0)
	assert_eq(CTBSpeed.normalize(0, 0.0), 1)
	assert_eq(CTBSpeed.head_start_ct(100, 0.0), 0)
	assert_eq(CTBSpeed.head_start_ct(100, 1.0), 500)
