extends GutTest


func test_gut_runner_argument_is_detected() -> void:
	assert_true(SaveSystem._is_gut_process(PackedStringArray([
		"-s",
		"res://addons/gut/gut_cmdln.gd",
		"-gexit",
	])))


func test_unrelated_script_argument_is_not_detected_as_gut() -> void:
	assert_false(SaveSystem._is_gut_process(PackedStringArray([
		"-s",
		"res://tools/export_data.gd",
	])))


func test_current_gut_process_resolves_slot_under_test_save_root() -> void:
	assert_true(SaveSystem._is_gut_process(OS.get_cmdline_args()))
	assert_eq(SaveSystem._get_save_dir(), "user://test_saves/")
	assert_eq(SaveSystem._get_slot_path(1), "user://test_saves/slot_1.json")
	assert_ne(SaveSystem._get_slot_path(1), "user://saves/slot_1.json")
