extends GutTest


func test_clear_restores_original_visual_state_and_focus_override() -> void:
	var control := Button.new()
	add_child_autofree(control)
	control.scale = Vector2(1.4, 0.8)
	control.pivot_offset = Vector2(7, 9)
	var original_style := StyleBoxFlat.new()
	original_style.bg_color = Color.RED
	control.add_theme_stylebox_override(&"focus", original_style)
	NavigationFocus.apply(control)
	NavigationFocus.clear(control)
	await get_tree().create_timer(0.1).timeout
	assert_eq(control.scale, Vector2(1.4, 0.8))
	assert_eq(control.pivot_offset, Vector2(7, 9))
	assert_true(control.has_theme_stylebox_override(&"focus"))
	assert_same(control.get_theme_stylebox(&"focus"), original_style)


func test_repeated_apply_and_clear_restore_controls_without_existing_override() -> void:
	var control := Button.new()
	add_child_autofree(control)
	control.scale = Vector2(0.9, 1.1)
	control.pivot_offset = Vector2(3, 5)
	NavigationFocus.apply(control)
	NavigationFocus.apply(control)
	NavigationFocus.clear(control)
	NavigationFocus.clear(control)
	await get_tree().create_timer(0.1).timeout
	assert_eq(control.scale, Vector2(0.9, 1.1))
	assert_eq(control.pivot_offset, Vector2(3, 5))
	assert_false(control.has_theme_stylebox_override(&"focus"))


func test_freed_highlighted_control_releases_saved_state() -> void:
	var control := Button.new()
	add_child(control)
	var instance_id := control.get_instance_id()
	NavigationFocus.apply(control)
	assert_true(NavigationFocus._states.has(instance_id))
	control.free()
	assert_false(NavigationFocus._states.has(instance_id))
