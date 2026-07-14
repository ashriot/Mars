extends GutTest


func test_button_focus_uses_seventy_percent_fill_and_dark_text_without_scaling() -> void:
	var control := Button.new()
	control.scale = Vector2(1.4, 0.8)
	control.pivot_offset = Vector2(7, 9)
	add_child_autofree(control)
	NavigationFocus.apply(control)
	var style := control.get_theme_stylebox(&"focus") as StyleBoxFlat
	assert_not_null(style)
	if style:
		assert_almost_eq(style.bg_color.a, 0.7, 0.001)
	assert_eq(control.get_theme_color(&"font_focus_color"), Color(0.19607843, 0.19607843, 0.19607843, 1))
	assert_eq(control.scale, Vector2(1.4, 0.8))
	assert_eq(control.pivot_offset, Vector2(7, 9))
	NavigationFocus.clear(control)


func test_clear_restores_authored_style_and_label_colors() -> void:
	var control := TextureButton.new()
	var surface := Panel.new()
	surface.name = "Panel"
	var label := Label.new()
	control.add_child(surface)
	control.add_child(label)
	control.set_meta("navigation_focus_surface", NodePath("Panel"))
	var original_style := StyleBoxFlat.new()
	original_style.bg_color = Color.BLUE
	surface.add_theme_stylebox_override(&"panel", original_style)
	label.add_theme_color_override(&"font_color", Color.GREEN)
	add_child_autofree(control)
	NavigationFocus.apply(control)
	assert_ne(surface.get_theme_stylebox(&"panel"), original_style)
	assert_eq(label.get_theme_color(&"font_color"), Color(0.19607843, 0.19607843, 0.19607843, 1))
	NavigationFocus.clear(control)
	assert_same(surface.get_theme_stylebox(&"panel"), original_style)
	assert_eq(label.get_theme_color(&"font_color"), Color.GREEN)


func test_freed_highlighted_control_releases_saved_state() -> void:
	var control := Button.new()
	add_child(control)
	var instance_id := control.get_instance_id()
	NavigationFocus.apply(control)
	assert_true(NavigationFocus._states.has(instance_id))
	control.free()
	assert_false(NavigationFocus._states.has(instance_id))


func test_apply_after_completed_clear_reuses_tree_exit_cleanup_safely() -> void:
	var control := Button.new()
	add_child_autofree(control)
	NavigationFocus.apply(control)
	NavigationFocus.clear(control)
	NavigationFocus.apply(control)
	assert_engine_error_count(0)
