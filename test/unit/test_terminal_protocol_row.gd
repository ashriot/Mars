extends GutTest

const RowScene := preload("res://src/map/terminal_protocol_row.tscn")

func _row() -> TerminalProtocolRow:
	var row := RowScene.instantiate() as TerminalProtocolRow
	add_child_autofree(row)
	return row

func test_configure_sets_stable_identity_text_upgrade_and_semantic_glyph() -> void:
	var row := _row()
	row.configure(&"opt_fin_up", &"terminal_finance", "INTERCEPT PAYMENT", "+10.0 BITS", true)
	assert_eq(row.get_choice_id(), &"opt_fin_up")
	assert_eq(row.get_action(), &"terminal_finance")
	assert_eq(row.title_label.text, "INTERCEPT PAYMENT")
	assert_eq(row.outcome_label.text, "+10.0 BITS")
	assert_true(row.upgraded_label.visible)
	assert_eq(row.glyph.action, &"terminal_finance")

func test_press_emits_choice_once_and_disabled_row_is_inert() -> void:
	var row := _row()
	row.configure(&"opt_scan", &"terminal_scan", "HIJACK LOCAL FEED", "SECTOR SCAN", false)
	watch_signals(row)
	row.emit_signal(&"pressed")
	assert_signal_emitted_with_parameters(row, "activated", [&"opt_scan"])
	row.set_interactable(false)
	row.emit_signal(&"pressed")
	assert_signal_emit_count(row, "activated", 1)
	assert_true(row.disabled)

func test_enabled_row_is_mouse_clickable_but_never_gui_focusable() -> void:
	var row := _row()
	row.set_interactable(true)
	assert_false(row.disabled)
	assert_eq(row.focus_mode, Control.FOCUS_NONE)
	assert_eq(row.mouse_filter, Control.MOUSE_FILTER_STOP)
	watch_signals(row)
	row.emit_signal(&"pressed")
	assert_signal_emit_count(row, "activated", 1)


func test_mouse_hover_controls_caret_without_assigning_focus() -> void:
	var row := _row()
	row.mouse_entered.emit()
	assert_true(row.caret_label.visible)
	assert_false(row.has_focus())
	row.mouse_exited.emit()
	assert_false(row.caret_label.visible)

func test_row_presentation_preserves_glyph_shape_and_terminal_color_hierarchy() -> void:
	var row := _row()
	assert_eq(row.glyph.custom_minimum_size, Vector2(48, 48))
	assert_eq(row.glyph.stretch_mode, TextureButton.STRETCH_KEEP_ASPECT_CENTERED)
	var title_color := row.title_label.get_theme_color(&"font_color")
	var outcome_color := row.outcome_label.get_theme_color(&"font_color")
	assert_gt(title_color.r, title_color.g)
	assert_gt(title_color.g, title_color.b)
	assert_almost_eq(outcome_color.r, 1.0, 0.01)
	assert_almost_eq(outcome_color.g, 1.0, 0.01)
	assert_almost_eq(outcome_color.b, 1.0, 0.01)
	assert_eq(row.title_label.get_theme_font_size(&"font_size"), 36)
	assert_eq(row.outcome_label.get_theme_font_size(&"font_size"), 28)
