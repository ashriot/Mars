extends GutTest

const REFERENCE_HEIGHT := 1080.0
const COMPACT_HEIGHT := 800.0
const DECK_CAP_FLOOR := 9.0
const DECK_CAP_RECOMMENDED := 12.0

const CAPITAL_H := 72
const FULL_STOP := 46

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
func _cap_height(font: Font, size: int, character: int) -> float:
	var rids := font.get_rids()
	if rids.is_empty():
		return 0.0
	var text_server := TextServerManager.get_primary_interface()
	var glyph := text_server.font_get_glyph_index(rids[0], size, character, 0)
	return -text_server.font_get_glyph_offset(rids[0], Vector2i(size, 0), glyph).y


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
		assert_eq(project_theme.get_type_variation_base(variation), &"Label")


func test_every_type_variation_clears_the_deck_cap_height_floor() -> void:
	var project_theme := ThemeDB.get_project_theme()
	var scale := COMPACT_HEIGHT / REFERENCE_HEIGHT

	for variation: StringName in EXPECTED_SIZES:
		var font := project_theme.get_font(&"font", variation)
		assert_not_null(font, "%s has a hydrated font" % variation)
		if font == null:
			continue
		var authored_size: int = EXPECTED_SIZES[variation]
		var cap_height := _cap_height(font, authored_size, CAPITAL_H)
		var rendered_cap := cap_height * scale
		assert_gte(
			rendered_cap,
			DECK_CAP_FLOOR,
			"%s renders %.2fpx caps at 1280x800, Valve's REQUIRED floor is %.1f" % [
				variation, rendered_cap, DECK_CAP_FLOOR,
			],
		)


func test_every_type_variation_meets_the_deck_cap_height_recommendation() -> void:
	var project_theme := ThemeDB.get_project_theme()
	var scale := COMPACT_HEIGHT / REFERENCE_HEIGHT

	for variation: StringName in EXPECTED_SIZES:
		var font := project_theme.get_font(&"font", variation)
		assert_not_null(font, "%s has a hydrated font" % variation)
		if font == null:
			continue
		var authored_size: int = EXPECTED_SIZES[variation]
		var cap_height := _cap_height(font, authored_size, CAPITAL_H)
		var rendered_cap := cap_height * scale
		assert_gte(
			rendered_cap,
			DECK_CAP_RECOMMENDED,
			"%s renders %.2fpx caps at 1280x800, Valve's RECOMMENDED target is %.1f" % [
				variation, rendered_cap, DECK_CAP_RECOMMENDED,
			],
		)


func test_cap_height_measurement_is_per_glyph() -> void:
	var project_theme := ThemeDB.get_project_theme()
	var font := project_theme.get_font(&"font", &"LabelMicro")
	assert_not_null(font, "LabelMicro has a hydrated font")
	if font == null:
		return
	var authored_size: int = EXPECTED_SIZES[&"LabelMicro"]
	var capital_height := _cap_height(font, authored_size, CAPITAL_H)
	var full_stop_height := _cap_height(font, authored_size, FULL_STOP)
	assert_gt(
		capital_height,
		full_stop_height * 2.0,
		(
			"a capital H (%.1f) must measure meaningfully taller than a full stop (%.1f) -- "
			+ "if this fails, the measurement has regressed to line height, which is identical "
			+ "for every glyph and would silently defeat the deck cap height floor test"
		) % [capital_height, full_stop_height],
	)
