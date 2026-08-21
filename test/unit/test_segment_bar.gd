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


func _bar() -> SegmentBar:
	var bar := SegmentBar.new()
	add_child_autofree(bar)
	return bar
