extends GutTest


func _loader(path: String) -> OptionalLocalModel3D:
	var loader := OptionalLocalModel3D.new()
	loader.local_resource_path = path
	loader.model_parent = Node3D.new()
	loader.placeholder = Node3D.new()
	loader.add_child(loader.model_parent)
	loader.add_child(loader.placeholder)
	add_child_autofree(loader)
	return loader


func test_existing_packed_scene_replaces_placeholder() -> void:
	var loader := _loader(
		"res://test/fixtures/presentation/optional_model_fixture.tscn",
	)
	assert_true(loader.try_load())
	assert_not_null(loader.loaded_model)
	assert_false(loader.placeholder.visible)
	assert_false(loader.using_placeholder)


func test_missing_scene_keeps_placeholder_without_partial_child() -> void:
	var loader := _loader(
		"res://assets/graphics/models/quaternius_local/missing.gltf",
	)
	assert_false(loader.try_load())
	assert_null(loader.loaded_model)
	assert_true(loader.placeholder.visible)
	assert_true(loader.using_placeholder)
	assert_eq(loader.model_parent.get_child_count(), 0)


func test_reload_clears_the_prior_instance_exactly_once() -> void:
	var loader := _loader(
		"res://test/fixtures/presentation/optional_model_fixture.tscn",
	)
	assert_true(loader.try_load())
	var first := loader.loaded_model
	assert_true(loader.try_load())
	assert_false(is_instance_valid(first))
	assert_eq(loader.model_parent.get_child_count(), 1)


func test_invalid_placeholder_after_success_restores_placeholder_state() -> void:
	var loader := _loader(
		"res://test/fixtures/presentation/optional_model_fixture.tscn",
	)
	assert_true(loader.try_load())
	loader.placeholder.free()
	assert_false(loader.try_load())
	assert_null(loader.loaded_model)
	assert_true(loader.using_placeholder)
