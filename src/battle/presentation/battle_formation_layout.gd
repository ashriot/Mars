extends RefCounted
class_name BattleFormationLayout

enum Layout { W, M }

const W_POSITIONS := {
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

const M_POSITIONS := {
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

const BOSS_POSITION := Vector3.ZERO
const LEFT_BOSS_ALLY_POSITION := Vector3(-4.4, 0.0, 0.0)
const RIGHT_BOSS_ALLY_POSITION := Vector3(4.4, 0.0, 0.0)


static func ordinary_transforms(count: int, layout: Layout) -> Array[Transform3D]:
	if count < 0 or count > 5:
		push_error("supports at most five ordinary enemies")
		return []
	if count == 0:
		return []
	var positions: Array = W_POSITIONS[count] if layout == Layout.W else M_POSITIONS[count]
	var transforms: Array[Transform3D] = []
	for position: Vector3 in positions:
		transforms.append(Transform3D(Basis.IDENTITY, position))
	return transforms


static func boss_transforms(ally_count: int) -> Dictionary:
	var transforms := {
		"boss": Transform3D(Basis.IDENTITY, BOSS_POSITION),
	}
	if ally_count >= 1:
		transforms.left_ally = Transform3D(Basis.IDENTITY, LEFT_BOSS_ALLY_POSITION)
	if ally_count >= 2:
		transforms.right_ally = Transform3D(Basis.IDENTITY, RIGHT_BOSS_ALLY_POSITION)
	return transforms
