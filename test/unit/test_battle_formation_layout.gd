extends GutTest


func _positions(transforms: Array[Transform3D]) -> Array[Vector3]:
	var values: Array[Vector3] = []
	for value: Transform3D in transforms:
		values.append(value.origin)
	return values


func test_w_uses_authored_slots_for_every_supported_count() -> void:
	var expected := {
		1: [Vector3(0.0, 0.0, -1.4)],
		2: [Vector3(-1.8, 0.0, 1.0), Vector3(1.8, 0.0, 1.0)],
		3: [
			Vector3(-3.6, 0.0, -1.0),
			Vector3(0.0, 0.0, -1.4),
			Vector3(3.6, 0.0, -1.0),
		],
		4: [
			Vector3(-3.6, 0.0, -1.0),
			Vector3(3.6, 0.0, -1.0),
			Vector3(-1.8, 0.0, 1.0),
			Vector3(1.8, 0.0, 1.0),
		],
		5: [
			Vector3(-3.6, 0.0, -1.0),
			Vector3(0.0, 0.0, -1.4),
			Vector3(3.6, 0.0, -1.0),
			Vector3(-1.8, 0.0, 1.0),
			Vector3(1.8, 0.0, 1.0),
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
		1: [Vector3(0.0, 0.0, 1.4)],
		2: [Vector3(-1.8, 0.0, -1.0), Vector3(1.8, 0.0, -1.0)],
		3: [
			Vector3(-3.6, 0.0, 1.0),
			Vector3(0.0, 0.0, 1.4),
			Vector3(3.6, 0.0, 1.0),
		],
		4: [
			Vector3(-1.8, 0.0, -1.0),
			Vector3(1.8, 0.0, -1.0),
			Vector3(-3.6, 0.0, 1.0),
			Vector3(3.6, 0.0, 1.0),
		],
		5: [
			Vector3(-1.8, 0.0, -1.0),
			Vector3(1.8, 0.0, -1.0),
			Vector3(-3.6, 0.0, 1.0),
			Vector3(0.0, 0.0, 1.4),
			Vector3(3.6, 0.0, 1.0),
		],
	}
	for count: int in expected:
		assert_eq(
			_positions(BattleFormationLayout.ordinary_transforms(count, BattleFormationLayout.Layout.M)),
			expected[count],
			"M count %d should use its authored slots" % count,
		)


func test_six_ordinary_enemies_is_rejected() -> void:
	var transforms := BattleFormationLayout.ordinary_transforms(6, BattleFormationLayout.Layout.W)
	assert_push_error("supports at most five ordinary enemies")
	assert_true(transforms.is_empty())


func test_boss_reserves_center_volume_and_two_outer_allies() -> void:
	var layout := BattleFormationLayout.boss_transforms(2)
	assert_eq(layout.boss, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	assert_eq(layout.left_ally, Transform3D(Basis.IDENTITY, Vector3(-4.4, 0.0, 0.0)))
	assert_eq(layout.right_ally, Transform3D(Basis.IDENTITY, Vector3(4.4, 0.0, 0.0)))
