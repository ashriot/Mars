extends GutTest

const REFERENCE_HEIGHT := 1080.0
const COMPACT_HEIGHT := 800.0
const DECK_CAP_FLOOR := 9.0

const EXPECTED_SIZES := {
	&"LabelMicro": 27,
	&"LabelLabel": 30,
	&"LabelValue": 33,
	&"LabelSub": 27,
}


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
		var cap_height := font.get_char_size("H".unicode_at(0), authored_size).y
		var rendered_cap := cap_height * scale
		assert_gte(
			rendered_cap,
			DECK_CAP_FLOOR,
			"%s renders %.2fpx caps at 1280x800, floor is %.1f" % [
				variation, rendered_cap, DECK_CAP_FLOOR,
			],
		)
