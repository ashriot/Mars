extends GutTest

const TerminalScene = preload("res://src/map/terminal.tscn")


func _payload(upgrade_key: String = "", facility: String = "TEST", bits: int = 12, alert: int = 10) -> Dictionary:
	return {
		"upgrade_key": upgrade_key,
		"bits": bits,
		"alert": alert,
		"facility_name": facility,
		"session_id": "TEST-SESSION",
	}


func _terminal(upgrade_key: String = "") -> Control:
	var terminal := TerminalScene.instantiate()
	add_child(terminal)
	terminal.setup(_payload(upgrade_key))
	await get_tree().process_frame
	return terminal


func test_setup_configures_five_structured_rows_and_one_upgrade() -> void:
	for upgrade_key in ["", "security", "scan", "medical", "finance"]:
		var terminal := await _terminal(upgrade_key)
		var ids: Array[StringName] = []
		var upgraded_count := 0
		for index in 5:
			var row: TerminalProtocolRow = terminal.get_protocol_row(index)
			ids.append(row.get_choice_id())
			upgraded_count += int(row.upgraded_label.visible)
		assert_eq(ids.size(), 5)
		assert_eq(ids.duplicate().reduce(func(unique, id): return unique + int(ids.count(id) == 1), 0), 5)
		assert_eq(upgraded_count, 0 if upgrade_key.is_empty() else 1)
		terminal.free()


func test_first_protocol_input_during_typing_only_finishes_animation() -> void:
	var terminal := await _terminal()
	watch_signals(terminal)
	assert_eq(terminal.interaction_state, terminal.TerminalState.TYPING)
	assert_true(terminal.handle_semantic_action(&"terminal_security"))
	assert_eq(terminal.interaction_state, terminal.TerminalState.READY)
	assert_signal_not_emitted(terminal, "option_selected")
	assert_true(terminal.handle_semantic_action(&"terminal_security"))
	assert_signal_emitted_with_parameters(terminal, "option_selected", [&"opt_sec"])
	clear_signal_watcher()
	terminal.free()


func test_protocols_one_through_four_execute_immediately_and_exactly_once() -> void:
	for index in 4:
		var terminal := await _terminal()
		terminal.finish_typing()
		watch_signals(terminal)
		assert_true(terminal.handle_semantic_action([&"terminal_security", &"terminal_scan", &"terminal_medical", &"terminal_finance"][index]))
		assert_signal_emit_count(terminal, "option_selected", 1)
		assert_eq(terminal.interaction_state, terminal.TerminalState.CLOSING)
		terminal.handle_semantic_action(&"terminal_security")
		assert_signal_emit_count(terminal, "option_selected", 1)
		clear_signal_watcher()
		terminal.free()


func test_extraction_requires_confirm_and_cancel_returns_to_ready() -> void:
	var terminal := await _terminal()
	terminal.finish_typing()
	watch_signals(terminal)
	assert_true(terminal.handle_semantic_action(&"terminal_extract"))
	assert_eq(terminal.interaction_state, terminal.TerminalState.CONFIRMING_EXTRACTION)
	assert_signal_not_emitted(terminal, "option_selected")
	assert_true(terminal.handle_semantic_action(&"terminal_scan"))
	assert_signal_not_emitted(terminal, "option_selected")
	assert_true(terminal.handle_semantic_action(&"cancel"))
	assert_eq(terminal.interaction_state, terminal.TerminalState.READY)
	assert_true(terminal.handle_semantic_action(&"terminal_extract"))
	assert_true(terminal.handle_semantic_action(&"confirm"))
	assert_signal_emitted_with_parameters(terminal, "option_selected", [&"opt_extract"])
	assert_eq(terminal.interaction_state, terminal.TerminalState.CLOSING)
	clear_signal_watcher()
	terminal.free()


func test_setup_resets_confirmation_typing_and_one_shot_state() -> void:
	var terminal := await _terminal()
	terminal.finish_typing()
	terminal.handle_semantic_action(&"terminal_extract")
	terminal.setup(_payload("medical", "SECOND", 25, 15))
	assert_eq(terminal.interaction_state, terminal.TerminalState.TYPING)
	assert_false(terminal.confirmation_panel.visible)
	assert_eq(terminal.get_protocol_row(2).get_choice_id(), &"opt_med_up")
	assert_false(terminal.close_button.disabled)
	terminal.free()


func test_incomplete_presentation_data_disables_every_protocol_but_can_close() -> void:
	var terminal := TerminalScene.instantiate()
	add_child_autofree(terminal)
	assert_false(terminal.setup({"facility_name": "BROKEN"}))
	for index in 5:
		assert_true(terminal.get_protocol_row(index).disabled)
	assert_false(terminal.close_button.disabled)
	watch_signals(terminal)
	assert_true(terminal.handle_semantic_action(&"cancel"))
	await get_tree().create_timer(0.3).timeout
	assert_signal_emit_count(terminal, "closed", 1)


func test_repeated_protocol_activation_is_single_shot_and_never_closes() -> void:
	var terminal := await _terminal()
	terminal.finish_typing()
	var counts := [0, 0]
	terminal.option_selected.connect(func(_choice): counts[0] += 1)
	terminal.closed.connect(func(): counts[1] += 1)
	terminal.get_protocol_row(1).emit_signal(&"pressed")
	terminal.get_protocol_row(3).emit_signal(&"pressed")
	terminal.handle_semantic_action(&"cancel")
	assert_eq(counts, [1, 0])
	assert_true(terminal.close_button.disabled)
	await get_tree().create_timer(0.3).timeout
	assert_eq(counts, [1, 0])
	await get_tree().process_frame


func test_repeated_explicit_close_emits_closed_once_and_no_option() -> void:
	var terminal := await _terminal()
	terminal.finish_typing()
	watch_signals(terminal)
	terminal.handle_semantic_action(&"cancel")
	terminal.handle_semantic_action(&"cancel")
	terminal.get_protocol_row(1).emit_signal(&"pressed")
	assert_signal_not_emitted(terminal, "option_selected")
	assert_signal_not_emitted(terminal, "closed")
	assert_true(terminal.close_button.disabled)
	await get_tree().create_timer(0.3).timeout
	assert_signal_not_emitted(terminal, "option_selected")
	assert_signal_emit_count(terminal, "closed", 1)
	terminal.queue_free()
	await get_tree().process_frame


func test_setup_invalidates_an_in_flight_explicit_close() -> void:
	var terminal := await _terminal()
	var counts := [0, 0]
	terminal.option_selected.connect(func(_choice): counts[0] += 1)
	terminal.closed.connect(func(): counts[1] += 1)

	terminal.handle_semantic_action(&"cancel")
	terminal.setup(_payload("medical", "SECOND", 25, 15))
	await get_tree().create_timer(0.3).timeout

	assert_true(is_instance_valid(terminal))
	assert_true(terminal.visible)
	assert_eq(terminal.modulate.a, 1.0)
	assert_string_contains(terminal.header_text.text, "SECOND")
	assert_eq(terminal.get_protocol_row(2).get_choice_id(), &"opt_med_up")
	assert_eq(counts, [0, 0])
	assert_false(terminal.close_button.disabled)

	terminal.finish_typing()
	terminal.get_protocol_row(2).emit_signal(&"pressed")
	terminal.get_protocol_row(3).emit_signal(&"pressed")
	terminal.handle_semantic_action(&"cancel")
	assert_eq(counts, [1, 0])
	await get_tree().create_timer(0.3).timeout
	assert_eq(counts, [1, 0])
	await get_tree().process_frame
