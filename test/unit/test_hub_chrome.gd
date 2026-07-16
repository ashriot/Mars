extends GutTest


func test_inactive_chrome_darkens_only_edges_and_restores_authored_style() -> void:
	var surface := Panel.new()
	var authored := StyleBoxFlat.new()
	authored.bg_color = Color(0.2, 0.3, 0.4, 0.8)
	authored.border_color = Color(0.8, 1.0, 0.2, 1.0)
	authored.shadow_color = Color(0.8, 1.0, 0.2, 0.5)
	surface.add_theme_stylebox_override(&"panel", authored)
	add_child_autofree(surface)
	HubChrome.capture(surface)
	HubChrome.set_active(surface, false)
	var inactive := surface.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(inactive.bg_color, authored.bg_color)
	assert_lt(inactive.border_color.get_luminance(), authored.border_color.get_luminance())
	assert_lt(inactive.shadow_color.get_luminance(), authored.shadow_color.get_luminance())
	HubChrome.set_active(surface, true)
	var restored := surface.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(restored.bg_color, authored.bg_color)
	assert_eq(restored.border_color, authored.border_color)
	assert_eq(restored.shadow_color, authored.shadow_color)
