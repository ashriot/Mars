extends GutTest

const FAMILIES := ["keyboard_mouse", "nintendo_switch", "nintendo_switch_2", "playstation", "steam_controller", "steam_deck", "xbox"]
const CURSORS := ["pointer_c", "hand_point", "hand_open", "hand_closed", "tool_hammer", "cursor_disabled", "busy_circle", "cross_small", "cursor_cogs"]

func test_runtime_glyph_folders_are_lowercase_svg_only() -> void:
	for family in FAMILIES:
		var dir := DirAccess.open("res://assets/graphics/glyphs/%s/vector" % family)
		assert_not_null(dir, family)
		for file_name in dir.get_files():
			if file_name.ends_with(".import"):
				continue
			assert_eq(file_name, file_name.to_lower(), file_name)
			assert_true(file_name.ends_with(".svg"), file_name)

func test_approved_cursor_set_is_complete() -> void:
	for cursor_name in CURSORS:
		assert_true(ResourceLoader.exists("res://assets/graphics/glyphs/cursors/outline/%s.svg" % cursor_name), cursor_name)
