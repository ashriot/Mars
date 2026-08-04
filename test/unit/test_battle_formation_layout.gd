extends GutTest


func _positions(transforms: Array[Transform3D]) -> Array[Vector3]:
	var values: Array[Vector3] = []
	for value: Transform3D in transforms:
		values.append(value.origin)
	return values


func test_w_uses_authored_slots_for_every_supported_count() -> void:
	var expected := {
		1: [Vector3(0.0, 0.0, -0.61)],
		2: [Vector3(-1.44, 0.0, 3.80), Vector3(1.44, 0.0, 3.80)],
		3: [
			Vector3(-5.00, 0.0, -0.21),
			Vector3(0.0, 0.0, -0.61),
			Vector3(5.00, 0.0, -0.21),
		],
		4: [
			Vector3(-5.00, 0.0, -0.21),
			Vector3(5.00, 0.0, -0.21),
			Vector3(-1.44, 0.0, 3.80),
			Vector3(1.44, 0.0, 3.80),
		],
		5: [
			Vector3(-5.00, 0.0, -0.21),
			Vector3(0.0, 0.0, -0.61),
			Vector3(5.00, 0.0, -0.21),
			Vector3(-1.44, 0.0, 3.80),
			Vector3(1.44, 0.0, 3.80),
		],
	}
	for count: int in expected:
		assert_eq(
			_positions(BattleFormationLayout.ordinary_transforms(count, BattleFormationLayout.Layout.W)),
			expected[count],
			"W count %d should use its authored slots" % count,
		)


func test_m_uses_authored_slots_for_every_supported_count() -> void:
	var expected := {
		1: [Vector3(0.0, 0.0, 3.70)],
		2: [Vector3(-2.70, 0.0, -0.71), Vector3(2.70, 0.0, -0.71)],
		3: [
			Vector3(-3.17, 0.0, 3.30),
			Vector3(0.0, 0.0, 3.70),
			Vector3(3.17, 0.0, 3.30),
		],
		4: [
			Vector3(-2.70, 0.0, -0.71),
			Vector3(2.70, 0.0, -0.71),
			Vector3(-3.17, 0.0, 3.30),
			Vector3(3.17, 0.0, 3.30),
		],
		5: [
			Vector3(-2.70, 0.0, -0.71),
			Vector3(2.70, 0.0, -0.71),
			Vector3(-3.17, 0.0, 3.30),
			Vector3(0.0, 0.0, 3.70),
			Vector3(3.17, 0.0, 3.30),
		],
	}
	for count: int in expected:
		assert_eq(
			_positions(BattleFormationLayout.ordinary_transforms(count, BattleFormationLayout.Layout.M)),
			expected[count],
			"M count %d should use its authored slots" % count,
		)


func test_mixed_rows_keep_at_least_four_world_units_of_depth_separation() -> void:
	for layout: BattleFormationLayout.Layout in [
		BattleFormationLayout.Layout.W,
		BattleFormationLayout.Layout.M,
	]:
		for count: int in [4, 5]:
			var positions := _positions(BattleFormationLayout.ordinary_transforms(count, layout))
			var minimum_z := positions[0].z
			var maximum_z := positions[0].z
			for position: Vector3 in positions:
				minimum_z = minf(minimum_z, position.z)
				maximum_z = maxf(maximum_z, position.z)
			assert_gte(
				maximum_z - minimum_z,
				4.0,
				"layout %s count %d keeps authored row depth" % [layout, count],
			)


func test_six_ordinary_enemies_is_rejected() -> void:
	var transforms := BattleFormationLayout.ordinary_transforms(6, BattleFormationLayout.Layout.W)
	assert_push_error("supports at most five ordinary enemies")
	assert_true(transforms.is_empty())


func test_boss_reserves_unchanged_center_and_outer_ally_transforms() -> void:
	var boss_only := BattleFormationLayout.boss_transforms(0)
	var one_ally := BattleFormationLayout.boss_transforms(1)
	var two_allies := BattleFormationLayout.boss_transforms(2)
	var boss_transform := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var left_transform := Transform3D(Basis.IDENTITY, Vector3(-4.4, 0.0, 0.0))
	var right_transform := Transform3D(Basis.IDENTITY, Vector3(4.4, 0.0, 0.0))

	assert_eq(boss_only, {"boss": boss_transform})
	assert_eq(one_ally, {"boss": boss_transform, "left_ally": left_transform})
	assert_eq(two_allies, {
		"boss": boss_transform,
		"left_ally": left_transform,
		"right_ally": right_transform,
	})
