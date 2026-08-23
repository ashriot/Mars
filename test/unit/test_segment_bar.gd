extends GutTest

const PALETTE := preload("res://data/theme/ui_palette.tres")


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

	# Read the layout _draw() would actually paint, rather than re-deriving
	# padding and x-stepping here in parallel — a parallel derivation can
	# stay green even when the real draw path's padding or stepping breaks.
	var leftmost := INF
	var rightmost := -INF
	for entry in bar.get_draw_quads():
		if entry.kind != &"track":
			continue
		for point in entry.quad:
			leftmost = minf(leftmost, point.x)
			rightmost = maxf(rightmost, point.x)

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


func test_wrapped_gauge_is_one_row_at_a_cap_of_ten() -> void:
	var bar := _guard_bar(10.0)

	assert_eq(bar.get_row_count(), 1)


func test_wrapped_gauge_is_three_rows_at_a_cap_of_thirty() -> void:
	var bar := _guard_bar(30.0)

	assert_eq(bar.get_row_count(), 3)


func test_wrapped_gauge_width_is_identical_at_every_cap() -> void:
	# Minimum-size width always reserves the full per_row columns, even
	# when the cap doesn't fill a row — a cap of 3 must be exactly as wide
	# as a cap of 10 or 30, not narrower, so every unit's gauge lines up.
	var narrow := _guard_bar(10.0)
	var wide := _guard_bar(30.0)
	var sparse := _guard_bar(3.0)

	assert_almost_eq(
		narrow.get_minimum_size().x,
		wide.get_minimum_size().x,
		0.01,
		"a ten-guard unit and a thirty-guard unit occupy the same width",
	)
	assert_almost_eq(
		narrow.get_minimum_size().x,
		sparse.get_minimum_size().x,
		0.01,
		"a three-guard unit reserves the same width as a ten-guard unit",
	)


func test_wrapped_gauge_grows_only_in_height_with_its_cap() -> void:
	var narrow := _guard_bar(10.0)
	var wide := _guard_bar(30.0)

	assert_lt(narrow.get_minimum_size().y, wide.get_minimum_size().y)


func test_wrapped_gauge_cell_size_never_rescales_to_fit_a_bigger_cap() -> void:
	var narrow := _guard_bar(10.0)
	var wide := _guard_bar(30.0)

	assert_eq(narrow.cell_size, wide.cell_size)


func test_wrapped_gauge_partial_cap_still_reserves_a_whole_row() -> void:
	var bar := _guard_bar(12.0)

	assert_eq(bar.get_row_count(), 2)


func test_wrapped_gauge_at_zero_cap_collapses_to_no_cells() -> void:
	# A unit with no guard mechanic (max_value <= 0) must draw nothing, not
	# one phantom empty cell reading as "1 guard, broken".
	var bar := _guard_bar(0.0)

	assert_eq(bar.get_row_count(), 0)
	assert_eq(bar.get_draw_quads().size(), 0)
	assert_eq(bar.get_minimum_size(), Vector2.ZERO)


func test_wrapped_draw_quads_stay_within_and_reach_minimum_size() -> void:
	# Mirrors test_negative_skew_drawn_cells_stay_within_minimum_size for
	# WRAPPED, across both axes: reads the real draw path via
	# get_draw_quads() rather than re-deriving row/column math here, and
	# checks the layout both stays inside get_minimum_size() and actually
	# reaches every edge of it (so a dropped row_gap, a wrapped-off column
	# step, or a fixed row all show up as a mismatch).
	var bar := _guard_bar(30.0)
	var minimum := bar.get_minimum_size()

	var leftmost := INF
	var rightmost := -INF
	var topmost := INF
	var bottommost := -INF
	for entry in bar.get_draw_quads():
		if entry.kind != &"track":
			continue
		for point in entry.quad:
			leftmost = minf(leftmost, point.x)
			rightmost = maxf(rightmost, point.x)
			topmost = minf(topmost, point.y)
			bottommost = maxf(bottommost, point.y)

	assert_almost_eq(leftmost, 0.0, 0.001)
	assert_almost_eq(rightmost, minimum.x, 0.001)
	assert_almost_eq(topmost, 0.0, 0.001)
	assert_almost_eq(bottommost, minimum.y, 0.001)


func test_wrapped_draw_quads_yields_track_per_cell_and_fill_up_to_value() -> void:
	var bar := _guard_bar(30.0)
	bar.value = 17.0

	var track_count := 0
	var fill_count := 0
	for entry in bar.get_draw_quads():
		if entry.kind == &"track":
			track_count += 1
		elif entry.kind == &"fill":
			fill_count += 1

	assert_eq(track_count, 30)
	assert_eq(fill_count, 17)


func test_wrapped_draw_quads_fill_precedes_unfilled_in_row_order() -> void:
	var bar := _guard_bar(30.0)
	bar.value = 17.0

	var kinds: Array[StringName] = []
	for entry in bar.get_draw_quads():
		kinds.append(entry.kind)

	var expected: Array[StringName] = []
	for i in 30:
		expected.append(&"track")
		if i < 17:
			expected.append(&"fill")

	assert_eq(kinds, expected)


func test_tally_inserts_a_group_gap_every_group_every_cells() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.TALLY
	bar.cells = 10
	bar.cell_size = Vector2(9, 24)
	bar.cell_gap = 3.0
	bar.group_every = 5
	bar.group_gap = 10.5
	bar.skew_px = 0.0

	var minimum := bar.get_minimum_size()

	assert_almost_eq(minimum.x, 10.0 * 9.0 + 9.0 * 3.0 + 10.5, 0.01)


func test_tally_without_grouping_has_no_extra_width() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.TALLY
	bar.cells = 10
	bar.cell_size = Vector2(9, 24)
	bar.cell_gap = 3.0
	bar.group_every = 0
	bar.skew_px = 0.0

	var minimum := bar.get_minimum_size()

	assert_almost_eq(minimum.x, 10.0 * 9.0 + 9.0 * 3.0, 0.01)


func test_ability_cost_sizes_itself_to_the_cost() -> void:
	var bar := _bar()
	bar.style = SegmentBar.Style.TALLY
	bar.cells = 3
	bar.cell_size = Vector2(9, 21)
	bar.cell_gap = 3.0
	bar.group_every = 5
	bar.skew_px = 0.0

	var minimum := bar.get_minimum_size()

	assert_almost_eq(minimum.x, 3.0 * 9.0 + 2.0 * 3.0, 0.01)


func test_tally_draw_quads_stay_within_and_reach_minimum_size() -> void:
	# Mirrors test_wrapped_draw_quads_stay_within_and_reach_minimum_size:
	# reads the real draw path via get_draw_quads() rather than re-deriving
	# the group-gap stepping here, so a dropped or mis-indexed group_gap
	# step shows up as a mismatch instead of staying invisible.
	var bar := _bar()
	bar.style = SegmentBar.Style.TALLY
	bar.cells = 10
	bar.cell_size = Vector2(9, 24)
	bar.cell_gap = 3.0
	bar.group_every = 5
	bar.group_gap = 10.5
	bar.skew_px = 3.0

	var minimum := bar.get_minimum_size()

	var leftmost := INF
	var rightmost := -INF
	var topmost := INF
	var bottommost := -INF
	for entry in bar.get_draw_quads():
		if entry.kind != &"track":
			continue
		for point in entry.quad:
			leftmost = minf(leftmost, point.x)
			rightmost = maxf(rightmost, point.x)
			topmost = minf(topmost, point.y)
			bottommost = maxf(bottommost, point.y)

	assert_almost_eq(leftmost, 0.0, 0.001)
	assert_almost_eq(rightmost, minimum.x, 0.001)
	assert_almost_eq(topmost, 0.0, 0.001)
	assert_almost_eq(bottommost, minimum.y, 0.001)


func _guard_bar(cap: float) -> SegmentBar:
	var bar := _bar()
	bar.style = SegmentBar.Style.WRAPPED
	bar.per_row = 10
	bar.cell_size = Vector2(12, 9)
	bar.cell_gap = 3.0
	bar.row_gap = 3.0
	bar.skew_px = 3.0
	bar.use_alarm_states = false
	bar.max_value = cap
	bar.value = cap
	return bar


func _bar() -> SegmentBar:
	var bar := SegmentBar.new()
	add_child_autofree(bar)
	return bar


func test_alarm_state_escalates_as_the_ratio_falls() -> void:
	var bar := _bar()
	bar.max_value = 100.0

	bar.value = 80.0
	assert_eq(bar.get_fill_state(), SegmentBar.FillState.OK)
	bar.value = 40.0
	assert_eq(bar.get_fill_state(), SegmentBar.FillState.WARN)
	bar.value = 10.0
	assert_eq(bar.get_fill_state(), SegmentBar.FillState.CRIT)


func test_state_changed_fires_only_on_a_real_transition() -> void:
	var bar := _bar()
	bar.max_value = 100.0
	bar.value = 100.0
	watch_signals(bar)

	bar.value = 90.0
	assert_signal_not_emitted(bar, "state_changed")

	bar.value = 40.0
	assert_signal_emitted(bar, "state_changed")


func test_a_gauge_without_alarm_states_stays_ok_at_any_value() -> void:
	var bar := _bar()
	bar.use_alarm_states = false
	bar.max_value = 100.0

	bar.value = 1.0

	assert_eq(bar.get_fill_state(), SegmentBar.FillState.OK)


func test_tween_to_replaces_its_predecessor_instead_of_racing_it() -> void:
	var bar := _bar()
	bar.max_value = 100.0
	bar.value = 100.0

	bar.tween_to(60.0, 0.2)
	var first := bar.get_active_tween()
	bar.tween_to(20.0, 0.2)
	var second := bar.get_active_tween()

	assert_not_null(second)
	assert_false(first.is_valid(), "the superseded tween is killed, not left running")
	assert_true(second.is_valid())


func test_tween_to_reaches_its_target_value() -> void:
	var bar := _bar()
	bar.max_value = 100.0
	bar.value = 100.0

	bar.tween_to(40.0, 0.05)
	await wait_seconds(0.15)

	assert_almost_eq(bar.value, 40.0, 0.001)


func test_pulse_processing_follows_the_pulse_setting() -> void:
	var bar := _bar()
	bar.pulse_when_critical = false

	assert_false(bar.is_processing())

	bar.pulse_when_critical = true

	assert_true(bar.is_processing())


func test_guard_gauge_stays_achromatic_and_calm_at_any_value() -> void:
	# Guard must never compete with the HP ramp: a nearly-broken guard is
	# still flat, still OK, and never pulses.
	var bar := _guard_bar(30.0)

	bar.value = 2.0

	assert_eq(bar.get_fill_state(), SegmentBar.FillState.OK)
	assert_eq(bar.get_fill_color(), bar.flat_color)


func test_fill_color_follows_the_alarm_ramp() -> void:
	var bar := _bar()
	bar.pulse_when_critical = false
	bar.max_value = 100.0

	bar.value = 80.0
	assert_eq(bar.get_fill_color(), bar.color_ok)
	bar.value = 40.0
	assert_eq(bar.get_fill_color(), bar.color_warn)
	bar.value = 10.0
	assert_eq(bar.get_fill_color(), bar.color_crit)


func test_alarm_thresholds_are_inclusive_at_the_boundary() -> void:
	var bar := _bar()
	bar.max_value = 100.0

	bar.value = 50.0
	assert_eq(bar.get_fill_state(), SegmentBar.FillState.WARN, "exactly warn_below is WARN")
	bar.value = 25.0
	assert_eq(bar.get_fill_state(), SegmentBar.FillState.CRIT, "exactly crit_below is CRIT")


func test_retuning_a_threshold_refreshes_state_immediately() -> void:
	var bar := _bar()
	bar.max_value = 100.0
	bar.value = 60.0
	assert_eq(bar.get_fill_state(), SegmentBar.FillState.OK)

	bar.crit_below = 0.9

	assert_eq(bar.get_fill_state(), SegmentBar.FillState.CRIT)


func test_collapsed_bar_with_no_cap_never_alarms() -> void:
	var bar := _bar()
	bar.max_value = 100.0
	bar.value = 10.0
	assert_eq(bar.get_fill_state(), SegmentBar.FillState.CRIT)

	bar.max_value = 0.0

	assert_eq(bar.get_fill_state(), SegmentBar.FillState.OK, "no cap means no mechanic, not a mechanic at zero")


func test_set_values_can_collapse_the_cap_to_zero() -> void:
	var bar := _bar()
	bar.set_values(50.0, 100.0)

	bar.set_values(0.0, 0.0)

	assert_eq(bar.max_value, 0.0)


func test_critical_pulse_breathes_the_fill_color() -> void:
	var bar := _bar()
	bar.max_value = 100.0
	bar.value = 10.0
	var resting := bar.get_fill_color()

	bar._phase = PI * 0.5   # sin peak -- poking private animation state directly is
	                         # acceptable for a unit test of private animation phase.
	var peak := bar.get_fill_color()

	# HSV .v is not a usable brightness proxy here: color_crit's red channel
	# is already at 1.0, so lightened() (which pulls every channel toward
	# white) can never raise max(r,g,b) further -- .v is pinned at 1.0 both
	# at rest and at peak. Luminance (a weighted sum of all three channels)
	# actually rises as green/blue lift toward white, so it's the metric
	# that reflects what "breathes brighter" means for this colour.
	assert_ne(peak, resting, "the critical fill breathes with the pulse phase")
	assert_gt(peak.get_luminance(), resting.get_luminance(), "breathing brightens, never dims or fades")


func test_should_process_only_runs_the_pulse_outside_the_editor() -> void:
	assert_false(SegmentBar.should_process(true, true), "editor hint suppresses processing even when pulse wants it")
	assert_true(SegmentBar.should_process(true, false), "outside the editor, a pulse request runs")


func test_pulse_phase_only_advances_while_critical() -> void:
	# is_processing() is driven by pulse_when_critical alone (see
	# should_process()), so _process() runs every frame regardless of
	# alarm state; it's _process()'s own internal guard that must keep the
	# phase pinned at rest outside CRIT. Advance real frames rather than
	# poking _phase, so a dropped guard actually shows up.
	var bar := _bar()
	bar.max_value = 100.0
	bar.value = 80.0
	bar.pulse_when_critical = true

	await wait_process_frames(5)

	assert_eq(bar._phase, 0.0, "phase must not advance outside CRIT")


func test_assigning_a_palette_adopts_its_alarm_ramp() -> void:
	var bar := _bar()

	bar.palette = PALETTE

	assert_eq(bar.color_ok, PALETTE.hp_ok)
	assert_eq(bar.color_warn, PALETTE.hp_warn)
	assert_eq(bar.color_crit, PALETTE.hp_crit)


func test_assigning_a_palette_adopts_its_achromatic_guard_as_the_flat_colour() -> void:
	var bar := _bar()

	bar.palette = PALETTE

	assert_eq(bar.flat_color, PALETTE.guard)
