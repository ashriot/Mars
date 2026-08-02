extends GutTest


func test_gut_runs_under_supported_godot_version() -> void:
	var version := Engine.get_version_info()
	assert_eq(version.major, 4)
	assert_eq(version.minor, 7)
	assert_eq(version.patch, 1)
