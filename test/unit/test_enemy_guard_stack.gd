extends GutTest


const GUARD_STACK_SCENE := preload("res://src/battle/presentation/enemy_guard_stack.tscn")
const GUARD_WIDTH := 220.0
const PIP_WIDTH := 21.0
const PIP_HEIGHT := 22.0
const PIP_STEP := 22.0
const WHITE := Color.WHITE
const MEDIUM_GRAY := Color(0.62, 0.65, 0.7, 1.0)
const DARK_GRAY := Color(0.34, 0.37, 0.42, 1.0)


func test_zero_guard_in_danger_shows_vulnerable_in_one_layer_slot() -> void:
	var stack := _stack()

	stack.render(0, true, false)

	assert_eq(_visible_pip_count(stack), 0)
	assert_true(_status_label(stack).visible)
	assert_eq(_status_label(stack).text, "VULNERABLE")
	assert_false(_guard_value(stack).visible)
	assert_eq(stack.get_visual_layer_count(), 1)
	assert_gte(
		stack.custom_minimum_size.y,
		ceilf(_label_ink_rect(_status_label(stack)).end.y),
	)


func test_zero_guard_breached_takes_precedence_over_vulnerable() -> void:
	var stack := _stack()

	stack.render(0, true, true)

	assert_eq(_visible_pip_count(stack), 0)
	assert_true(_status_label(stack).visible)
	assert_eq(_status_label(stack).text, "BREACHED")
	assert_eq(stack.get_visual_layer_count(), 1)
	assert_gte(
		stack.custom_minimum_size.y,
		ceilf(_label_ink_rect(_status_label(stack)).end.y),
	)


func test_seven_guard_fills_seven_white_pips_in_the_first_layer() -> void:
	var stack := _stack()

	stack.render(7, false, false)

	assert_eq(_visible_pip_count(stack), 7)
	assert_eq(_visible_pip_count_in_layer(stack, 0), 7)
	assert_eq(_visible_pip_count_in_layer(stack, 1), 0)
	assert_eq(_visible_pip_count_in_layer(stack, 2), 0)
	assert_eq(_layer(stack, 0).get_child(6).modulate, WHITE)
	assert_eq(_guard_value(stack).text, "7")
	assert_eq(_guard_value(stack).position, _layer(stack, 0).position + _pip(stack, 0, 6).position)
	assert_eq(stack.get_visual_layer_count(), 1)


func test_ten_guard_places_the_value_in_the_tenth_first_layer_pip() -> void:
	var stack := _stack()

	stack.render(10, false, false)

	assert_eq(_visible_pip_count_in_layer(stack, 0), 10)
	assert_eq(_layer(stack, 0).get_child(9).modulate, WHITE)
	assert_eq(_guard_value(stack).text, "10")
	assert_eq(_guard_value(stack).position.y, _layer(stack, 0).position.y)
	assert_gte(_label_ink_rect(_guard_value(stack)).position.x, 0.0)
	assert_lte(_label_ink_rect(_guard_value(stack)).end.x, GUARD_WIDTH)
	assert_eq(stack.get_visual_layer_count(), 1)


func test_thirteen_guard_layers_medium_gray_below_three_white_pips() -> void:
	var stack := _stack()

	stack.render(13, false, false)

	assert_eq(_visible_pip_count_in_layer(stack, 0), 10)
	assert_eq(_visible_pip_count_in_layer(stack, 1), 3)
	assert_eq(_visible_pip_count_in_layer(stack, 2), 0)
	assert_eq(_layer(stack, 0).get_child(0).modulate, MEDIUM_GRAY)
	assert_eq(_layer(stack, 1).get_child(2).modulate, WHITE)
	assert_eq(_guard_value(stack).text, "13")
	assert_eq(_guard_value(stack).position, _layer(stack, 1).position + _pip(stack, 1, 2).position)
	assert_eq(stack.get_visual_layer_count(), 2)
	assert_gte(stack.custom_minimum_size.y, 27.0)
	assert_gte(stack.custom_minimum_size.y, ceilf(_label_ink_rect(_guard_value(stack)).end.y))


func test_twenty_three_guard_uses_dark_and_medium_completed_layers() -> void:
	var stack := _stack()

	stack.render(23, false, false)

	assert_eq(_visible_pip_count_in_layer(stack, 0), 10)
	assert_eq(_visible_pip_count_in_layer(stack, 1), 10)
	assert_eq(_visible_pip_count_in_layer(stack, 2), 3)
	assert_eq(_layer(stack, 0).get_child(0).modulate, DARK_GRAY)
	assert_eq(_layer(stack, 1).get_child(0).modulate, MEDIUM_GRAY)
	assert_eq(_layer(stack, 2).get_child(2).modulate, WHITE)
	assert_eq(_guard_value(stack).text, "23")
	assert_eq(_guard_value(stack).position, _layer(stack, 2).position + _pip(stack, 2, 2).position)
	assert_eq(stack.get_visual_layer_count(), 3)
	assert_gte(stack.custom_minimum_size.y, 32.0)
	assert_gte(stack.custom_minimum_size.y, ceilf(_label_ink_rect(_guard_value(stack)).end.y))


func test_thirty_guard_fills_all_layers_and_places_value_in_last_pip() -> void:
	var stack := _stack()

	stack.render(30, false, false)

	assert_eq(_visible_pip_count(stack), 30)
	assert_eq(_guard_value(stack).text, "30")
	assert_eq(_guard_value(stack).position.y, _layer(stack, 2).position.y + _pip(stack, 2, 9).position.y)
	assert_gte(_label_ink_rect(_guard_value(stack)).position.x, 0.0)
	assert_lte(_label_ink_rect(_guard_value(stack)).end.x, GUARD_WIDTH)
	assert_eq(stack.get_visual_layer_count(), 3)


func test_guard_above_thirty_is_clamped_without_mutating_the_input() -> void:
	var stack := _stack()
	var supplied_guard := 31

	stack.render(supplied_guard, false, false)

	assert_eq(supplied_guard, 31)
	assert_eq(_visible_pip_count(stack), 30)
	assert_eq(_guard_value(stack).text, "30")
	assert_eq(stack.get_visual_layer_count(), 3)


func test_scene_authored_layers_align_columns_and_step_down_by_five_pixels() -> void:
	var stack := _stack()

	for column in 10:
		assert_eq(_pip(stack, 0, column).position.x, _pip(stack, 1, column).position.x)
		assert_eq(_pip(stack, 1, column).position.x, _pip(stack, 2, column).position.x)
	assert_eq(_layer(stack, 1).position.y - _layer(stack, 0).position.y, 5.0)
	assert_eq(_layer(stack, 2).position.y - _layer(stack, 1).position.y, 5.0)


func test_scene_authored_guard_visuals_fit_the_compact_width_at_full_depth() -> void:
	var stack := _stack()
	stack.render(30, false, false)
	await get_tree().process_frame
	var compact_bounds := Rect2(Vector2.ZERO, Vector2(GUARD_WIDTH, stack.size.y))

	assert_eq(stack.custom_minimum_size.x, GUARD_WIDTH)
	assert_eq(stack.size.x, GUARD_WIDTH)
	for layer_index in 3:
		var layer := _layer(stack, layer_index)
		assert_eq(layer.size.x, GUARD_WIDTH)
		for pip_index in 10:
			var pip := _pip(stack, layer_index, pip_index)
			var visual_rect := Rect2(layer.position + pip.position, pip.size)
			assert_true(
				compact_bounds.encloses(visual_rect),
				"layer %d column %d stays inside the 220 px guard slot" % [
					layer_index + 1,
					pip_index + 1,
				],
			)
			assert_eq(pip.size.y, PIP_HEIGHT, "guard pips retain their authored height")
			assert_eq(pip.size.x, PIP_WIDTH, "guard pips retain their authored width")
			assert_eq(
				pip.position.x,
				floorf(pip.position.x),
				"guard columns keep readable integer X positions",
			)
			if pip_index > 0:
				assert_eq(
					pip.position.x - _pip(stack, layer_index, pip_index - 1).position.x,
					PIP_STEP,
					"adjacent guard pips retain a one-pixel gap",
				)
				assert_eq(
					pip.position.x - _pip(stack, layer_index, pip_index - 1).get_rect().end.x,
					1.0,
					"adjacent guard visuals do not merge",
				)
	var guard_value := _guard_value(stack)
	assert_eq(guard_value.get_theme_font_size(&"font_size"), 20)
	assert_eq(guard_value.get_theme_constant(&"outline_size"), 4)
	assert_eq(guard_value.get_theme_color(&"font_outline_color"), Color.BLACK)
	assert_eq(guard_value.scale, Vector2.ONE)
	for guard in [10, 20, 30]:
		stack.render(guard, false, false)
		var value_ink := _label_ink_rect(guard_value)
		assert_gte(value_ink.position.x, 0.0)
		assert_lte(
			value_ink.end.x,
			GUARD_WIDTH,
			"guard %d outlined value remains inside the 220 px guard slot" % guard,
		)
	assert_eq(_status_label(stack).size.x, GUARD_WIDTH)
	assert_eq(_status_label(stack).get_theme_font_size(&"font_size"), 24)
	assert_eq(_status_label(stack).get_theme_constant(&"outline_size"), 6)
	assert_eq(_status_label(stack).get_theme_color(&"font_outline_color"), Color.BLACK)


func _stack() -> Control:
	var stack := GUARD_STACK_SCENE.instantiate() as Control
	add_child_autofree(stack)
	return stack


func _layer(stack: Control, layer_index: int) -> Control:
	return stack.get_child(layer_index) as Control


func _pip(stack: Control, layer_index: int, pip_index: int) -> TextureRect:
	return _layer(stack, layer_index).get_child(pip_index) as TextureRect


func _visible_pip_count(stack: Control) -> int:
	var count := 0
	for layer_index in 3:
		count += _visible_pip_count_in_layer(stack, layer_index)
	return count


func _visible_pip_count_in_layer(stack: Control, layer_index: int) -> int:
	var count := 0
	for pip: TextureRect in _layer(stack, layer_index).get_children():
		if pip.visible:
			count += 1
	return count


func _guard_value(stack: Control) -> Label:
	return stack.get_node("GuardValue") as Label


func _status_label(stack: Control) -> Label:
	return stack.get_node("StatusLabel") as Label


func _label_ink_rect(label: Label) -> Rect2:
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var text_size := Vector2(
		font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
		font.get_height(font_size),
	)
	var ink_position := label.position
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			ink_position.x += (label.size.x - text_size.x) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			ink_position.x += label.size.x - text_size.x
	match label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			ink_position.y += (label.size.y - text_size.y) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			ink_position.y += label.size.y - text_size.y
	return Rect2(ink_position, text_size).grow(
		float(label.get_theme_constant(&"outline_size")),
	)
