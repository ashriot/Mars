extends GutTest

const DisplayProfileServiceScript = preload("res://src/ui/display/display_profile_service.gd")
const ResponsiveFixture = preload("res://test/fixtures/responsive_viewport_fixture.gd")


func test_profile_boundaries_include_deck_and_small_desktop_windows() -> void:
	assert_eq(DisplayProfileServiceScript.profile_for(Vector2i(1280, 800)), DisplayProfileServiceScript.Profile.COMPACT)
	assert_eq(DisplayProfileServiceScript.profile_for(Vector2i(1366, 900)), DisplayProfileServiceScript.Profile.COMPACT)
	assert_eq(DisplayProfileServiceScript.profile_for(Vector2i(1920, 800)), DisplayProfileServiceScript.Profile.COMPACT)
	assert_eq(DisplayProfileServiceScript.profile_for(Vector2i(1920, 1080)), DisplayProfileServiceScript.Profile.DESKTOP)


func test_startup_policy_uses_native_fullscreen_only_for_compact_displays() -> void:
	var deck := DisplayProfileServiceScript.startup_policy_for(Vector2i(1280, 800))
	assert_eq(deck.size, Vector2i(1280, 800))
	assert_eq(deck.mode, DisplayServer.WINDOW_MODE_FULLSCREEN)
	var desktop := DisplayProfileServiceScript.startup_policy_for(Vector2i(2560, 1440))
	assert_eq(desktop.size, Vector2i(1920, 1080))
	assert_eq(desktop.mode, DisplayServer.WINDOW_MODE_WINDOWED)


func test_expanded_deck_canvas_and_centered_world_safe_rect() -> void:
	var logical := DisplayProfileServiceScript.expanded_logical_size_for(Vector2i(1280, 800))
	assert_eq(logical, Vector2(1920, 1200))
	assert_eq(DisplayProfileServiceScript.safe_rect_for(logical), Rect2(0, 60, 1920, 1080))
	assert_eq(ResponsiveFixture.output_scale_for(Vector2i(1280, 800)), 2.0 / 3.0)


func test_4k_output_keeps_the_reference_composition_at_two_x_scale() -> void:
	var output := Vector2i(3840, 2160)

	assert_almost_eq(
		DisplayProfileServiceScript.output_scale_for(output),
		2.0,
		0.001,
		"4K should render the reference canvas at 2x",
	)
	assert_eq(
		DisplayProfileServiceScript.expanded_logical_size_for(output),
		Vector2(1920, 1080),
		"4K must retain the authored 1920x1080 logical composition",
	)
	assert_eq(
		DisplayProfileServiceScript.safe_rect_for(Vector2(1920, 1080)),
		Rect2(Vector2.ZERO, DisplayProfileServiceScript.REFERENCE_SIZE),
		"the reference canvas should need no letterboxing",
	)


func test_zero_metrics_are_ignored_and_duplicate_metrics_do_not_emit() -> void:
	var service := DisplayProfileServiceScript.new()
	add_child_autofree(service)
	watch_signals(service)
	assert_false(service.update_metrics(Vector2i.ZERO, Vector2.ZERO))
	assert_true(service.update_metrics(Vector2i(1280, 800), Vector2(1920, 1200)))
	assert_false(service.update_metrics(Vector2i(1280, 800), Vector2(1920, 1200)))
	assert_signal_emit_count(service, "profile_changed", 1)
