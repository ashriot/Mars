extends GutTest

const FAMILIES := ["keyboard_mouse", "nintendo_switch", "nintendo_switch_2", "playstation", "steam_controller", "steam_deck", "xbox"]
const CURSORS := ["pointer_c", "hand_point", "hand_point_e", "hand_point_n", "hand_open", "hand_closed", "tool_hammer", "cursor_disabled", "busy_circle", "cross_small", "cursor_cogs"]
const BATTLE_KEYBOARD_GLYPHS := [
	"keyboard_1.svg", "keyboard_2.svg", "keyboard_3.svg", "keyboard_4.svg",
	"keyboard_q.svg", "keyboard_e.svg",
]
const TERMINAL_KEYBOARD_GLYPHS := ["keyboard_1.svg", "keyboard_2.svg", "keyboard_3.svg", "keyboard_4.svg", "keyboard_5.svg"]


func test_battle_keyboard_glyph_sources_are_curated() -> void:
	for file_name: String in BATTLE_KEYBOARD_GLYPHS:
		assert_true(
			FileAccess.file_exists("res://assets/graphics/glyphs/keyboard_mouse/vector/%s" % file_name),
			file_name,
		)


func test_terminal_keyboard_glyph_sources_are_curated() -> void:
	for file_name: String in TERMINAL_KEYBOARD_GLYPHS:
		assert_true(
			FileAccess.file_exists("res://assets/graphics/glyphs/keyboard_mouse/vector/%s" % file_name),
			file_name,
		)


func test_keyboard_five_glyph_contains_visible_dark_numeral_pixels() -> void:
	var texture := load("res://assets/graphics/glyphs/keyboard_mouse/vector/keyboard_5.svg") as Texture2D
	assert_not_null(texture)
	var image := texture.get_image()
	var dark_opaque_pixels := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.9 and pixel.get_luminance() < 0.25:
				dark_opaque_pixels += 1
	assert_gt(dark_opaque_pixels, 0, "keyboard 5 must render a visible numeral")


func test_runtime_glyph_folders_are_lowercase_svg_only() -> void:
	var glyph_root := DirAccess.open("res://assets/graphics/glyphs")
	var actual_families := Array(glyph_root.get_directories())
	actual_families.erase("cursors")
	actual_families.sort()
	var expected_families := FAMILIES.duplicate()
	expected_families.sort()
	assert_eq(actual_families, expected_families, "literal family directory names")
	for family in FAMILIES:
		var dir := DirAccess.open("res://assets/graphics/glyphs/%s/vector" % family)
		assert_not_null(dir, family)
		for file_name in dir.get_files():
			if file_name.ends_with(".import"):
				continue
			assert_eq(file_name, file_name.to_lower(), file_name)
			assert_true(file_name.ends_with(".svg"), file_name)

func test_approved_cursor_set_is_complete() -> void:
	var cursor_dir := DirAccess.open("res://assets/graphics/glyphs/cursors/outline")
	var actual_sources: Array[String] = []
	for file_name in cursor_dir.get_files():
		if file_name.ends_with(".svg"):
			actual_sources.append(file_name)
	actual_sources.sort()
	var expected_sources: Array[String] = []
	for cursor_name in CURSORS:
		expected_sources.append(cursor_name + ".svg")
	expected_sources.sort()
	assert_eq(actual_sources, expected_sources, "exact eleven cursor SVG sources; .import sidecars ignored")
	for cursor_name in CURSORS:
		assert_true(ResourceLoader.exists("res://assets/graphics/glyphs/cursors/outline/%s.svg" % cursor_name), cursor_name)
