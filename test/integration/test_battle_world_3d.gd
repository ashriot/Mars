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
	assert_eq(environment.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	assert_eq(environment.background_color, Color(0.06, 0.085, 0.13, 1.0))
	assert_eq(environment.ambient_light_color, Color(0.22, 0.28, 0.40, 1.0))
	assert_almost_eq(environment.ambient_light_energy, 0.45, 0.001)
	assert_almost_eq(environment.tonemap_exposure, 1.0, 0.001)


func test_room_uses_mobile_lighting_hierarchy() -> void:
	var world := _world()
	var room := world.get_node("IndustrialRoom3D")
	var key := room.get_node("RoomKeyLight") as DirectionalLight3D
	var fill := room.get_node("RoomFillLight") as OmniLight3D
	var accent := room.get_node_or_null("RoomAccentLight") as OmniLight3D
	var bounce := room.get_node("RoomBounceLight") as DirectionalLight3D
	var front := room.get_node_or_null("RoomFrontLight") as DirectionalLight3D
	assert_not_null(key)
	assert_not_null(fill)
	assert_not_null(accent)
	assert_not_null(bounce)
	assert_null(front)
	if accent == null:
		return
	assert_almost_eq(key.rotation_degrees.x, -52.0, 0.001)
	assert_almost_eq(key.rotation_degrees.y, -34.0, 0.001)
	assert_almost_eq(key.rotation_degrees.z, 0.0, 0.001)
	assert_eq(key.light_color, Color(0.76, 0.86, 1.0, 1.0))
	assert_almost_eq(key.light_energy, 1.35, 0.001)
	assert_true(key.shadow_enabled)
	assert_eq(fill.position, Vector3(-2.5, 2.6, 5.0))
	assert_eq(fill.light_color, Color(0.34, 0.52, 0.85, 1.0))
	assert_almost_eq(fill.light_energy, 1.25, 0.001)
	assert_almost_eq(fill.omni_range, 9.0, 0.001)
	assert_false(fill.shadow_enabled)
	assert_eq(accent.position, Vector3(0.0, 3.6, -5.5))
	assert_eq(accent.light_color, Color(0.92, 0.28, 0.18, 1.0))
	assert_almost_eq(accent.light_energy, 1.10, 0.001)
	assert_almost_eq(accent.omni_range, 7.0, 0.001)
	assert_false(accent.shadow_enabled)
	assert_almost_eq(bounce.light_energy, 0.20, 0.001)
	assert_almost_eq(bounce.light_specular, 0.0, 0.001)
	assert_false(bounce.shadow_enabled)
	var room_lights: Array[Light3D] = [key, fill, accent, bounce]
	var shadow_light_count := 0
	for light: Light3D in room_lights:
		if light.shadow_enabled:
			shadow_light_count += 1
	assert_eq(shadow_light_count, 1)


func test_room_builds_a_closed_three_bay_shell_without_backdrop() -> void:
	var world := _world()
	var room := world.get_node("IndustrialRoom3D")
	assert_null(room.get_node_or_null("BattleBackdrop"))
	var shell := room.get_node("RoomShell")
	var floor := shell.get_node("Floor") as MeshInstance3D
	assert_not_null(floor)
	if floor != null:
		assert_gte(
			(floor.mesh as BoxMesh).size.z,
			18.0,
			"the floor must reach the camera-side entry, not stop at the nearest bay",
		)
	var canopy := shell.get_node_or_null("EntryCanopy") as MeshInstance3D
	assert_not_null(canopy, "the entry canopy must close the camera-side ceiling gap")
	if canopy != null:
		var canopy_material := canopy.mesh.surface_get_material(0) as StandardMaterial3D
		assert_true(
			canopy_material.emission_enabled,
			"the camera-side ceiling needs a visible underside instead of reading as empty black space",
		)
	var near_ceiling := shell.get_node("BayNear/CeilingPanel") as MeshInstance3D
	var near_ceiling_material := near_ceiling.mesh.surface_get_material(0) as StandardMaterial3D
	assert_true(
		near_ceiling_material.emission_enabled,
		"every bay ceiling needs the same readable underside as the camera-side entry",
	)
	var ceiling_backer := shell.get_node_or_null("CeilingBacker") as MeshInstance3D
	assert_not_null(
		ceiling_backer,
		"a continuous ceiling backer must prevent gaps between the detailed bay modules from exposing the clear color",
	)
	if ceiling_backer != null:
		assert_gte(
			(ceiling_backer.mesh as BoxMesh).size.z,
			20.0,
			"the ceiling backer must span the complete room, including the camera-side entry",
		)
	assert_not_null(
		shell.get_node_or_null("EntryLeftWall"),
		"the entry must continue the left wall up to the camera",
	)
	assert_not_null(
		shell.get_node_or_null("EntryRightWall"),
		"the entry must continue the right wall up to the camera",
	)
	assert_not_null(shell.get_node("BackWall/LeftPanel"))
	assert_not_null(shell.get_node("BackWall/CenterBulkhead"))
	assert_not_null(shell.get_node("BackWall/RightPanel"))
	var expected_bays := {
		"BayNear": Vector3(0.0, 0.0, 2.5),
		"BayMiddle": Vector3(0.0, 0.0, -1.5),
		"BayRear": Vector3(0.0, 0.0, -5.5),
	}
	for bay_name: String in expected_bays:
		var bay := shell.get_node(bay_name) as Node3D
		assert_not_null(bay)
		assert_eq(bay.position, expected_bays[bay_name])
		assert_not_null(bay.get_node("LeftWall"))
		assert_not_null(bay.get_node("RightWall"))
		assert_not_null(bay.get_node("LeftSupport"))
		assert_not_null(bay.get_node("RightSupport"))
		assert_not_null(bay.get_node("CeilingPanel"))
		assert_not_null(bay.get_node("CeilingBeam"))
		assert_not_null(bay.get_node("PracticalLight"))


func test_camera_side_floor_overlaps_the_entry_walls() -> void:
	var world := _world()
	var shell := world.get_node("IndustrialRoom3D/RoomShell")
	var floor := shell.get_node("Floor") as MeshInstance3D

	for wall_path: String in ["EntryLeftWall", "EntryRightWall"]:
		var wall := shell.get_node(wall_path) as MeshInstance3D
		_assert_world_bounds_overlap(
			floor,
			wall,
			"%s must overlap the floor so the room cannot expose the clear color at its base" % wall_path,
		)


func test_camera_side_ceiling_overlaps_the_entry_walls() -> void:
	var world := _world()
	var shell := world.get_node("IndustrialRoom3D/RoomShell")
	var ceiling := shell.get_node("CeilingBacker") as MeshInstance3D

	for wall_path: String in ["EntryLeftWall", "EntryRightWall"]:
		var wall := shell.get_node(wall_path) as MeshInstance3D
		_assert_world_bounds_overlap(
			wall,
			ceiling,
			"%s must overlap the ceiling so the room cannot expose the clear color at its top edge" % wall_path,
		)


func _assert_world_bounds_overlap(first: MeshInstance3D, second: MeshInstance3D, message: String) -> void:
	var overlap := _world_bounds(first).intersection(_world_bounds(second))
	assert_gt(overlap.size.x, 0.0, "%s (x)" % message)
	assert_gt(overlap.size.y, 0.0, "%s (y)" % message)
	assert_gt(overlap.size.z, 0.0, "%s (z)" % message)


func _world_bounds(mesh_instance: MeshInstance3D) -> AABB:
	var local_bounds := mesh_instance.mesh.get_aabb()
	var world_bounds := AABB()
	var initialized := false
	for x: float in [local_bounds.position.x, local_bounds.end.x]:
		for y: float in [local_bounds.position.y, local_bounds.end.y]:
			for z: float in [local_bounds.position.z, local_bounds.end.z]:
				var point := mesh_instance.global_transform * Vector3(x, y, z)
				if initialized:
					world_bounds = world_bounds.expand(point)
				else:
					world_bounds = AABB(point, Vector3.ZERO)
					initialized = true
	return world_bounds


func test_room_nested_local_modules_all_keep_tracked_placeholders() -> void:
	var world := _world()
	var room := world.get_node("IndustrialRoom3D")
	var nodes: Array[Node] = []
	for node: Node in room.find_children("*", "", true, false):
		if node is OptionalLocalModel3D:
			nodes.append(node)
	assert_gte(nodes.size(), 20)
	for node: Node in nodes:
		var loader := node as OptionalLocalModel3D
		assert_not_null(loader.model_parent)
		assert_not_null(loader.placeholder)
		assert_true(loader.placeholder is GeometryInstance3D)
		assert_false(loader.local_resource_path.is_empty())
	var left_vent := room.get_node("EdgeDressing/LeftVent") as OptionalLocalModel3D
	assert_not_null(left_vent)
	assert_not_null(left_vent.model_parent)
	assert_not_null(left_vent.placeholder)
	assert_same(left_vent.model_parent, left_vent.get_node("ModelPivot"))
	assert_same(left_vent.placeholder, left_vent.get_node("Placeholder"))
	assert_eq(left_vent.local_resource_path, \
		"res://assets/graphics/models/quaternius_local/environment/industrial/Prop_Vent_Wide.gltf")
	var right_vent := room.get_node("EdgeDressing/RightVent") as OptionalLocalModel3D
	assert_not_null(right_vent)
	assert_not_null(right_vent.model_parent)
	assert_not_null(right_vent.placeholder)
	assert_same(right_vent.model_parent, right_vent.get_node("ModelPivot"))
	assert_same(right_vent.placeholder, right_vent.get_node("Placeholder"))
	assert_eq(right_vent.local_resource_path, \
		"res://assets/graphics/models/quaternius_local/environment/industrial/Prop_Vent_Wide.gltf")
	var left_cable := room.get_node("EdgeDressing/LeftCable") as OptionalLocalModel3D
	assert_not_null(left_cable)
	assert_not_null(left_cable.model_parent)
	assert_not_null(left_cable.placeholder)
	assert_same(left_cable.model_parent, left_cable.get_node("ModelPivot"))
	assert_same(left_cable.placeholder, left_cable.get_node("Placeholder"))
	assert_eq(left_cable.local_resource_path, \
		"res://assets/graphics/models/quaternius_local/environment/industrial/Prop_Cable_1.gltf")
	var right_cable := room.get_node("EdgeDressing/RightCable") as OptionalLocalModel3D
	assert_not_null(right_cable)
	assert_not_null(right_cable.model_parent)
	assert_not_null(right_cable.placeholder)
	assert_same(right_cable.model_parent, right_cable.get_node("ModelPivot"))
	assert_same(right_cable.placeholder, right_cable.get_node("Placeholder"))
	assert_eq(right_cable.local_resource_path, \
		"res://assets/graphics/models/quaternius_local/environment/industrial/Prop_Cable_1.gltf")
	var frame := room.get_node("RoomShell/BackWall/DoorFrameModel") \
		as OptionalLocalModel3D
	var door := room.get_node("RoomShell/BackWall/DoorModel") \
		as OptionalLocalModel3D
	assert_eq(frame.local_resource_path, \
		"res://assets/graphics/models/quaternius_local/environment/industrial/Door_Frame_A.gltf")
	assert_eq(door.local_resource_path, \
		"res://assets/graphics/models/quaternius_local/environment/industrial/Door_Metal.gltf")
	for loader: OptionalLocalModel3D in [frame, door]:
		var pivot_scale := loader.model_parent.scale
		assert_gte(pivot_scale.x, 0.5)
		assert_lte(pivot_scale.x, 2.0)
		assert_gte(pivot_scale.y, 0.5)
		assert_lte(pivot_scale.y, 2.0)
		assert_gte(pivot_scale.z, 0.5)
		assert_lte(pivot_scale.z, 2.0)


func test_world_loads_optional_models_nested_below_room_root() -> void:
	var world := _world()
	var branch := Node3D.new()
	var container := Node3D.new()
	var loader := OptionalLocalModel3D.new()
	loader.local_resource_path = \
		"res://test/fixtures/presentation/optional_model_fixture.tscn"
	loader.model_parent = Node3D.new()
	loader.placeholder = MeshInstance3D.new()
	loader.add_child(loader.model_parent)
	loader.add_child(loader.placeholder)
	branch.add_child(container)
	container.add_child(loader)
	add_child_autofree(branch)
	world._load_optional_local_models(branch)
	assert_false(loader.using_placeholder)
	assert_not_null(loader.loaded_model)
	assert_false(loader.placeholder.visible)


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
