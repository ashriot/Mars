extends GutTest

const TerminalScene = preload("res://src/map/terminal.tscn")


func _terminal(upgrade_key: String = "") -> Control:
	var terminal := TerminalScene.instantiate()
	add_child(terminal)
	terminal.setup({
		"upgrade_key": upgrade_key,
		"bits": 12,
		"alert": 10,
		"facility_name": "TEST",
		"session_id": "TEST-SESSION",
	})
	return terminal


func test_protocol_numbers_and_links_are_unique_for_standard_and_upgraded() -> void:
	for upgrade_key in ["", "security", "scan", "medical", "finance"]:
		var terminal := _terminal(upgrade_key)
		for number in range(1, 6):
			assert_eq(terminal.final_text_content.count("%d ->" % number), 1)
		assert_string_contains(terminal.final_text_content, "ENTER CHOICE [1-5]")
		var expected_tags: Array[String] = ["opt_sec", "opt_scan", "opt_med", "opt_fin", "opt_extract"]
		if not upgrade_key.is_empty():
			var upgrade_tags := {
				"security": "opt_sec",
				"scan": "opt_scan",
				"medical": "opt_med",
				"finance": "opt_fin",
			}
			var base_tag: String = upgrade_tags[upgrade_key]
			expected_tags[expected_tags.find(base_tag)] += "_up"
		for tag in expected_tags:
			assert_string_contains(terminal.final_text_content, "[url=%s]" % tag)
		for tag in ["opt_sec", "opt_scan", "opt_med", "opt_fin"]:
			var should_be_upgraded: bool = expected_tags.has(tag + "_up")
			assert_eq(terminal.final_text_content.contains("[url=%s_up]" % tag), should_be_upgraded)
		terminal.free()


func test_repeated_link_click_is_single_shot_and_never_closes() -> void:
	var terminal := _terminal()
	var counts := [0, 0]
	terminal.option_selected.connect(func(_choice): counts[0] += 1)
	terminal.closed.connect(func(): counts[1] += 1)
	terminal._on_text_link_clicked("opt_scan")
	terminal._on_text_link_clicked("opt_fin")
	terminal._on_close_button_pressed()
	assert_eq(counts, [1, 0])
	assert_true(terminal.close_button.disabled)
	await get_tree().create_timer(0.3).timeout
	assert_eq(counts, [1, 0])
	await get_tree().process_frame


func test_repeated_explicit_close_emits_closed_once_and_no_option() -> void:
	var terminal := _terminal()
	var counts := [0, 0]
	terminal.option_selected.connect(func(_choice): counts[0] += 1)
	terminal.closed.connect(func(): counts[1] += 1)
	terminal._on_close_button_pressed()
	terminal._on_close_button_pressed()
	terminal._on_text_link_clicked("opt_scan")
	assert_eq(counts, [0, 0])
	assert_true(terminal.close_button.disabled)
	await get_tree().create_timer(0.3).timeout
	assert_eq(counts, [0, 1])
	terminal.queue_free()
	await get_tree().process_frame


func test_setup_invalidates_an_in_flight_explicit_close() -> void:
	var terminal := _terminal()
	var counts := [0, 0]
	terminal.option_selected.connect(func(_choice): counts[0] += 1)
	terminal.closed.connect(func(): counts[1] += 1)

	terminal._on_close_button_pressed()
	terminal.setup({
		"upgrade_key": "medical",
		"bits": 25,
		"alert": 15,
		"facility_name": "SECOND",
		"session_id": "SECOND-SESSION",
	})
	await get_tree().create_timer(0.3).timeout

	assert_true(is_instance_valid(terminal))
	assert_true(terminal.visible)
	assert_eq(terminal.modulate.a, 1.0)
	assert_string_contains(terminal.final_text_content, "SECOND")
	assert_string_contains(terminal.final_text_content, "[url=opt_med_up]")
	assert_eq(counts, [0, 0])
	assert_false(terminal.close_button.disabled)

	terminal._on_text_link_clicked("opt_med_up")
	terminal._on_text_link_clicked("opt_fin")
	terminal._on_close_button_pressed()
	assert_eq(counts, [1, 0])
	await get_tree().create_timer(0.3).timeout
	assert_eq(counts, [1, 0])
	await get_tree().process_frame
