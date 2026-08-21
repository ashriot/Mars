extends GutTest


func test_pips_minimum_size_covers_every_cell_its_gaps_and_the_skew() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.cell_size = Vector2(21, 36)
	bar.cell_gap = 4.5
	bar.skew_px = 6.45

	var minimum := bar.get_minimum_size()

	assert_almost_eq(minimum.x, 10.0 * 21.0 + 9.0 * 4.5 + 6.45, 0.01)
	assert_almost_eq(minimum.y, 36.0, 0.01)


func test_pips_report_full_partial_and_empty_cell_counts() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.max_value = 1000.0
	bar.value = 655.0

	assert_eq(bar.get_full_cell_count(), 6)
	assert_almost_eq(bar.get_partial_cell_fill(), 0.55, 0.001)


func test_pips_at_full_value_have_no_partial_cell() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.max_value = 1000.0
	bar.value = 1000.0

	assert_eq(bar.get_full_cell_count(), 10)
	assert_almost_eq(bar.get_partial_cell_fill(), 0.0, 0.001)


func test_pips_at_zero_are_entirely_empty() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.max_value = 1000.0
	bar.value = 0.0

	assert_eq(bar.get_full_cell_count(), 0)
	assert_almost_eq(bar.get_partial_cell_fill(), 0.0, 0.001)


func test_value_above_max_clamps_rather_than_overfilling() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.max_value = 1000.0
	bar.value = 4000.0

	assert_eq(bar.get_full_cell_count(), 10)
	assert_almost_eq(bar.get_partial_cell_fill(), 0.0, 0.001)


func test_build_quad_corners_match_hand_computed_values_at_known_skew() -> void:
	# x=0, y0=0, y1=h=36, w=21, skew=+6.45:
	#   o0 = skew * (0.5 - 0/36)  =  3.225
	#   o1 = skew * (0.5 - 36/36) = -3.225
	var quad := SegmentBar.build_quad(0.0, 0.0, 36.0, 21.0, 36.0, 6.45)

	assert_almost_eq(quad[0], Vector2(3.225, 0.0), Vector2(0.001, 0.001))
	assert_almost_eq(quad[1], Vector2(24.225, 0.0), Vector2(0.001, 0.001))
	assert_almost_eq(quad[2], Vector2(17.775, 36.0), Vector2(0.001, 0.001))
	assert_almost_eq(quad[3], Vector2(-3.225, 36.0), Vector2(0.001, 0.001))


func test_negative_skew_drawn_cells_stay_within_minimum_size() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.cell_size = Vector2(21, 36)
	bar.cell_gap = 4.5
	bar.skew_px = -6.45

	var minimum := bar.get_minimum_size()
	var pad := SegmentBar.left_pad(bar.skew_px)

	var leftmost := INF
	var rightmost := -INF
	var x := pad
	for i in bar.cells:
		var quad := SegmentBar.build_quad(x, 0.0, bar.cell_size.y, bar.cell_size.x, bar.cell_size.y, bar.skew_px)
		for point in quad:
			leftmost = minf(leftmost, point.x)
			rightmost = maxf(rightmost, point.x)
		x += bar.cell_size.x + bar.cell_gap

	assert_almost_eq(leftmost, 0.0, 0.001)
	assert_almost_eq(rightmost, minimum.x, 0.001)


func test_max_value_of_zero_reports_entirely_empty_rather_than_full() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.PIPS
	bar.cells = 10
	bar.max_value = 1000.0
	bar.value = 1000.0

	bar.max_value = 0.0

	assert_eq(bar.get_full_cell_count(), 0)
	assert_almost_eq(bar.get_partial_cell_fill(), 0.0, 0.001)


func _bar() -> SegmentBar:
	var bar := SegmentBar.new()
	add_child_autofree(bar)
	return bar
