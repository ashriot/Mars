extends GutTest


func test_gut_runs_under_supported_godot_4() -> void:
	assert_eq(Engine.get_version_info().major, 4)
	assert_eq(Engine.get_version_info().minor, 7)
