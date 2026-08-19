extends GutTest

const PALETTE_PATH := "res://data/theme/ui_palette.tres"

const REQUIRED_COLORS: Array[StringName] = [
	&"panel", &"panel_hi",
	&"stroke", &"stroke_hi", &"stroke_warm",
	&"ink", &"ink_dim", &"ink_faint", &"ink_hi",
	&"accent",
	&"hp_ok", &"hp_warn", &"hp_crit",
	&"guard", &"threat",
]


func test_palette_resource_defines_every_required_color() -> void:
	var palette := load(PALETTE_PATH) as UIPalette

	assert_not_null(palette)
	for property: StringName in REQUIRED_COLORS:
		assert_true(
			palette.get(property) is Color,
			"palette defines %s as a Color" % property,
		)


func test_guard_is_achromatic_so_it_never_competes_with_the_hp_ramp() -> void:
	var palette := load(PALETTE_PATH) as UIPalette

	assert_lt(palette.guard.s, 0.10, "guard reads as a neutral steel white")


func test_hp_ramp_starts_achromatic_and_alarms_warm() -> void:
	var palette := load(PALETTE_PATH) as UIPalette

	assert_lt(palette.hp_ok.s, 0.30, "a healthy unit is achromatic steel")
	assert_gt(palette.hp_warn.s, 0.50, "warn is unmistakably warm")
	assert_gt(palette.hp_crit.s, 0.50, "crit is unmistakably warm")


func test_hp_ramp_escalates_from_cool_through_amber_to_red() -> void:
	var palette := load(PALETTE_PATH) as UIPalette

	assert_between(palette.hp_ok.h, 0.45, 0.75, "ok sits in the cool blues")
	assert_between(palette.hp_warn.h, 0.05, 0.15, "warn sits in the ambers")
	assert_true(
		palette.hp_crit.h <= 0.03 or palette.hp_crit.h >= 0.97,
		"crit sits at red",
	)
