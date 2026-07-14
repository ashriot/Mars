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

func test_focus_presentation_uses_terminal_caret_without_toggle_state() -> void:
	var row := _row()
	row.grab_focus()
	await get_tree().process_frame
	assert_true(row.caret_label.visible)
	row.release_focus()
	await get_tree().process_frame
	assert_false(row.caret_label.visible)
