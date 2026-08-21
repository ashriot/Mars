extends GutTest

const ResponsiveFixture = preload("res://test/fixtures/responsive_viewport_fixture.gd")
const ThemeBootstrapScript = preload("res://src/ui/theme_bootstrap.gd")

const DECK_OUTPUT := Vector2i(1280, 800)
const DECK_CAP_FLOOR := 9.0
const DECK_CAP_RECOMMENDED := 12.0

const EXPECTED_SIZES := {
	&"LabelMicro": 27,
	&"LabelLabel": 30,
	&"LabelValue": 33,
	&"LabelSub": 27,
}


## Cap height is the distance from the baseline to the top of a capital H.
## Font.get_char_size().y and Font.get_height() both return LINE height --
## ascent plus descent, identical for every glyph including a period -- which
## overstates glyph height by roughly a third and would let a typeface slip
## under Valve's floor while this test passed. TextServer glyph metrics are the
## only per-glyph measurement available, and the glyph offset's negated y is
## the baseline-to-top distance.
## Theme.has_font() resolves through the type-variation base chain (LabelMicro
## -> Label) all the way to default_font, so it reports true even when nothing
## was ever hydrated onto the variation itself -- it cannot detect a deleted
## hydration loop. get_font_list() only lists fonts actually set on that exact
## theme_type, which is the check that catches that regression.
func _has_own_font(theme: Theme, variation: StringName) -> bool:
	return theme.get_font_list(variation).has(&"font")


func _cap_height(font: Font, size: int, character: int) -> float:
	var rids := font.get_rids()
	if rids.is_empty():
		fail_test("font %s has no RIDs to measure glyphs with" % font.resource_path)
		return 0.0
	var text_server := TextServerManager.get_primary_interface()
	var glyph := text_server.font_get_glyph_index(rids[0], size, character, 0)
	if glyph == 0:
		fail_test(
			"font %s has no glyph for character %d at size %d" % [
				font.resource_path, character, size,
			]
		)
		return 0.0
	return -text_server.font_get_glyph_offset(rids[0], Vector2i(size, 0), glyph).y


## Shared body for the two legibility gates below: fetches the font actually
## hydrated onto each variation (not inherited from default_font), measures
## its rendered cap height at the Deck's real output scale, and asserts it
## clears `threshold`. `label` distinguishes a hard requirement from a target
## in the failure message so a reader can tell which is which.
func _assert_cap_height_clears(threshold: float, label: String) -> void:
	var project_theme := ThemeDB.get_project_theme()
	var scale := ResponsiveFixture.output_scale_for(DECK_OUTPUT)

	for variation: StringName in EXPECTED_SIZES:
		assert_true(
			_has_own_font(project_theme, variation),
			"%s has a font hydrated onto the variation itself, not inherited from default_font" % variation,
		)
		if not _has_own_font(project_theme, variation):
			continue
		var font := project_theme.get_font(&"font", variation)
		var authored_size := project_theme.get_font_size(&"font_size", variation)
		var cap_height := _cap_height(font, authored_size, "H".unicode_at(0))
		var rendered_cap := cap_height * scale
		assert_gte(
			rendered_cap,
			threshold,
			"%s renders %.2fpx caps at 1280x800, Valve's %s is %.1f" % [
				variation, rendered_cap, label, threshold,
			],
		)


func test_every_type_variation_declares_its_authored_size() -> void:
	var project_theme := ThemeDB.get_project_theme()

	for variation: StringName in EXPECTED_SIZES:
		assert_true(
			project_theme.has_font_size(&"font_size", variation),
			"%s declares a font size" % variation,
		)
		assert_eq(
			project_theme.get_font_size(&"font_size", variation),
			EXPECTED_SIZES[variation],
			"%s is authored at its comfort size" % variation,
		)


func test_every_type_variation_derives_from_label() -> void:
	var project_theme := ThemeDB.get_project_theme()

	for variation: StringName in EXPECTED_SIZES:
		assert_eq(
			project_theme.get_type_variation_base(variation),
			&"Label",
			"%s derives from Label" % variation,
		)


func test_theme_bootstrap_hydrates_every_declared_variation() -> void:
	var bootstrap_variations := ThemeBootstrapScript.TYPE_VARIATIONS.duplicate()
	bootstrap_variations.sort()
	var expected_variations := EXPECTED_SIZES.keys()
	expected_variations.sort()
	assert_eq(
		bootstrap_variations,
		expected_variations,
		"ThemeBootstrap.TYPE_VARIATIONS must hydrate exactly the variations this test guards -- "
		+ "a typo in either list would silently create a stray theme type or leave a variation "
		+ "unhydrated and falling back to default_font without either test noticing",
	)


func test_every_type_variation_clears_the_deck_cap_height_floor() -> void:
	_assert_cap_height_clears(DECK_CAP_FLOOR, "REQUIRED floor")


func test_every_type_variation_meets_the_deck_cap_height_recommendation() -> void:
	_assert_cap_height_clears(DECK_CAP_RECOMMENDED, "RECOMMENDED target")


func test_cap_height_measurement_is_per_glyph() -> void:
	var project_theme := ThemeDB.get_project_theme()
	assert_true(
		_has_own_font(project_theme, &"LabelMicro"),
		"LabelMicro has a font hydrated onto the variation itself, not inherited from default_font",
	)
	if not _has_own_font(project_theme, &"LabelMicro"):
		return
	var font := project_theme.get_font(&"font", &"LabelMicro")
	var authored_size := project_theme.get_font_size(&"font_size", &"LabelMicro")
	var capital_height := _cap_height(font, authored_size, "H".unicode_at(0))
	var full_stop_height := _cap_height(font, authored_size, ".".unicode_at(0))
	assert_gt(
		capital_height,
		full_stop_height * 2.0,
		(
			"a capital H (%.1f) must measure meaningfully taller than a full stop (%.1f) -- "
			+ "if this fails, the measurement has regressed to line height, which is identical "
			+ "for every glyph and would silently defeat the deck cap height floor test"
		) % [capital_height, full_stop_height],
	)
