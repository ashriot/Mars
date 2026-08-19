extends GutTest

const PALETTE := preload("res://data/theme/ui_palette.tres")

const REQUIRED_COLORS: Array[StringName] = [
	&"panel", &"panel_hi",
	&"stroke", &"stroke_hi", &"stroke_warm",
	&"ink", &"ink_dim", &"ink_faint", &"ink_hi",
	&"accent",
	&"hp_ok", &"hp_warn", &"hp_crit",
	&"guard", &"threat",
]

## Every colour except the four deliberately-warm signal colours must stay
## cool, or a hurt unit stops being the only warm thing on screen.
const COOL_COLORS: Array[StringName] = [
	&"panel", &"panel_hi", &"stroke", &"stroke_hi",
	&"ink", &"ink_dim", &"ink_faint", &"ink_hi",
	&"accent", &"hp_ok", &"guard",
]


func test_palette_resource_defines_every_required_color() -> void:
	assert_not_null(PALETTE)
	for property: StringName in REQUIRED_COLORS:
		assert_true(
			PALETTE.get(property) is Color,
			"palette defines %s as a Color" % property,
		)


func test_palette_declares_exactly_the_required_colors() -> void:
	var declared: Array[StringName] = []
	for property: Dictionary in PALETTE.get_property_list():
		if property.type == TYPE_COLOR and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			declared.append(property.name)

	assert_eq(
		declared.size(), REQUIRED_COLORS.size(),
		"the palette's colour membership changed; update REQUIRED_COLORS as a deliberate design decision",
	)
	for property: StringName in REQUIRED_COLORS:
		assert_true(
			property in declared,
			"%s is missing from the palette" % property,
		)
	for property: StringName in declared:
		assert_true(
			property in REQUIRED_COLORS,
			"%s is a new colour not accounted for in REQUIRED_COLORS" % property,
		)


func test_guard_is_achromatic_so_it_never_competes_with_the_hp_ramp() -> void:
	assert_lt(PALETTE.guard.s, 0.15, "guard reads as a neutral steel white")


func test_hp_ramp_starts_achromatic_and_alarms_warm() -> void:
	assert_lt(PALETTE.hp_ok.s, 0.30, "a healthy unit is achromatic steel")
	assert_gt(PALETTE.hp_warn.s, 0.50, "warn is unmistakably warm")
	assert_gt(PALETTE.hp_crit.s, 0.50, "crit is unmistakably warm")


func test_hp_ramp_escalates_from_cool_through_amber_to_red() -> void:
	assert_between(PALETTE.hp_ok.h, 0.45, 0.75, "ok sits in the cool blues")
	assert_between(PALETTE.hp_warn.h, 0.05, 0.15, "warn sits in the ambers")

	var hue_from_red := minf(PALETTE.hp_crit.h, 1.0 - PALETTE.hp_crit.h)
	assert_lt(
		hue_from_red, 0.03,
		"crit sits at red, not in the orange band threat occupies (hue %.4f)" % PALETTE.hp_crit.h,
	)


func test_only_the_alarm_colors_are_warm() -> void:
	for property: StringName in COOL_COLORS:
		var color: Color = PALETTE.get(property)
		assert_between(
			color.h, 0.45, 0.75,
			"%s must stay cool; only hp_warn, hp_crit, threat and stroke_warm may be warm" % property,
		)


func test_strokes_are_hairlines_not_fills() -> void:
	for property: StringName in [&"stroke", &"stroke_hi", &"stroke_warm"]:
		var color: Color = PALETTE.get(property)
		assert_between(
			color.a, 0.1, 0.6,
			"%s must stay a translucent hairline, not opaque fill" % property,
		)


func test_panels_are_semi_transparent_surfaces() -> void:
	for property: StringName in [&"panel", &"panel_hi"]:
		var color: Color = PALETTE.get(property)
		assert_lt(
			color.a, 1.0,
			"%s must stay a semi-transparent surface, not opaque" % property,
		)
