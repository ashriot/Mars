extends GutTest

const BattleWorldScene := preload("res://src/battle/presentation/battle_world_3d.tscn")


func _world() -> BattleWorld3D:
	var world := BattleWorldScene.instantiate() as BattleWorld3D
	add_child_autofree(world)
	return world


func test_world_exposes_stable_camera_enemy_and_hud_nodes() -> void:
	var world := _world()
	assert_not_null(world.camera)
	assert_true(world.camera.current)
	assert_not_null(world.enemy_views)
	assert_not_null(world.hud_layer)
	assert_eq(world.hud_layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_world_raises_enemy_views_without_changing_local_formation_height() -> void:
	var world := _world()
	assert_eq(world.enemy_views.position, Vector3(0.0, 1.0, 0.0))
	var local_slots := BattleFormationLayout.ordinary_transforms(
		5,
		BattleFormationLayout.Layout.W,
	)
	for slot: Transform3D in local_slots:
		assert_eq(slot.origin.y, 0.0)


func test_world_environment_uses_readable_industrial_ambient_light() -> void:
	var world := _world()
	var world_environment := world.get_node("WorldEnvironment") as WorldEnvironment
	assert_not_null(world_environment)
	var environment := world_environment.environment
	assert_not_null(environment)
	assert_eq(environment.background_color, Color(0.035, 0.055, 0.085, 1.0))
	assert_eq(environment.ambient_light_color, Color(0.52, 0.58, 0.68, 1.0))
	assert_almost_eq(environment.ambient_light_energy, 1.1, 0.0001)


func test_room_uses_broad_neutral_readability_lighting() -> void:
	var world := _world()
	var room := world.get_node("IndustrialRoom3D")
	var key := room.get_node("RoomKeyLight") as DirectionalLight3D
	var fill := room.get_node("RoomFillLight") as OmniLight3D
	assert_not_null(key)
	assert_not_null(fill)
	assert_almost_eq(key.light_energy, 1.6, 0.0001)
	assert_true(key.shadow_enabled)
	assert_eq(fill.position, Vector3(0.0, 3.6, 4.0))
	assert_eq(fill.light_color, Color(0.82, 0.88, 1.0, 1.0))
	assert_eq(fill.light_energy, 5.0)
	assert_eq(fill.omni_range, 18.0)
	assert_false(fill.shadow_enabled)


func test_room_keeps_a_tracked_backdrop_behind_optional_local_modules() -> void:
	var world := _world()
	var room := world.get_node("IndustrialRoom3D")
	var backdrop := room.get_node_or_null("BattleBackdrop") as MeshInstance3D
	assert_not_null(backdrop)
	if backdrop == null:
		return
	assert_true(backdrop.visible)
	assert_eq(backdrop.position, Vector3(0.0, 2.5, -7.0))
	assert_eq(backdrop.scale, Vector3(1.5, 1.25, 1.0))
	assert_true(backdrop.mesh is BoxMesh)


func test_room_uses_eight_optional_local_modules_with_tracked_placeholders() -> void:
	var world := _world()
	var room := world.get_node("IndustrialRoom3D")
	var expected_paths := [
		"res://assets/graphics/models/quaternius_local/environment/industrial/WallAstra_Straight_Flat.gltf",
		"res://assets/graphics/models/quaternius_local/environment/industrial/TopAstra_Straight.gltf",
		"res://assets/graphics/models/quaternius_local/environment/industrial/BottomMetal_Straight.gltf",
		"res://assets/graphics/models/quaternius_local/environment/industrial/Platform_Metal.gltf",
		"res://assets/graphics/models/quaternius_local/environment/industrial/Column_Astra.gltf",
		"res://assets/graphics/models/quaternius_local/environment/industrial/Prop_Light_Wide.gltf",
		"res://assets/graphics/models/quaternius_local/environment/industrial/Prop_Vent_Wide.gltf",
		"res://assets/graphics/models/quaternius_local/environment/industrial/Prop_Cable_1.gltf",
	]
	var loaders: Array[OptionalLocalModel3D] = []
	for child: Node in room.get_children():
		if child is OptionalLocalModel3D:
			loaders.append(child)
	assert_eq(loaders.size(), 8)
	var actual_paths: Array[String] = []
	for loader: OptionalLocalModel3D in loaders:
		actual_paths.append(loader.local_resource_path)
		assert_not_null(loader.model_parent)
		assert_not_null(loader.placeholder)
		assert_true(loader.placeholder is MeshInstance3D)
	assert_eq(actual_paths, expected_paths)


func test_five_ordinary_views_are_adopted_and_placed_in_authored_order() -> void:
	var world := _world()
	var expected := BattleFormationLayout.ordinary_transforms(5, BattleFormationLayout.Layout.W)
	for index: int in 5:
		var view := Node3D.new()
		assert_true(world.place_ordinary_view(view, index, 5, BattleFormationLayout.Layout.W))
		assert_eq(view.get_parent(), world.enemy_views)
		assert_eq(view.transform, expected[index])


func test_sixth_ordinary_view_is_rejected_without_adoption_or_motion() -> void:
	var world := _world()
	var sixth := Node3D.new()
	var initial_transform := Transform3D(Basis.from_euler(Vector3(0.1, 0.2, 0.3)), Vector3(9.0, 8.0, 7.0))
	sixth.transform = initial_transform
	assert_false(world.place_ordinary_view(sixth, 5, 6, BattleFormationLayout.Layout.M))
	assert_null(sixth.get_parent())
	assert_eq(sixth.transform, initial_transform)
	sixth.free()


func test_boss_and_allies_use_reserved_center_and_outer_volumes() -> void:
	var world := _world()
	var boss := Node3D.new()
	var left_ally := Node3D.new()
	var right_ally := Node3D.new()
	assert_true(world.place_boss_view(boss))
	assert_true(world.place_boss_view(left_ally, 0))
	assert_true(world.place_boss_view(right_ally, 1))
	assert_eq(boss.position, Vector3.ZERO)
	assert_eq(left_ally.position, Vector3(-4.4, 0.0, 0.0))
	assert_eq(right_ally.position, Vector3(4.4, 0.0, 0.0))
	assert_eq(boss.get_parent(), world.enemy_views)
	assert_eq(left_ally.get_parent(), world.enemy_views)
	assert_eq(right_ally.get_parent(), world.enemy_views)


func test_encounter_defaults_to_w_formation() -> void:
	var encounter := Encounter.new()
	assert_eq(encounter.enemy_formation, BattleFormationLayout.Layout.W)
