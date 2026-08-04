extends RefCounted
class_name BattleFormationLayout

enum Layout { W, M }

const W_BACK_LEFT := Vector3(-5.25, 0.0, -2.20)
const W_BACK_CENTER := Vector3(0.0, 0.0, -2.60)
const W_BACK_RIGHT := Vector3(5.25, 0.0, -2.20)
const W_FRONT_LEFT := Vector3(-1.72, 0.0, 1.80)
const W_FRONT_RIGHT := Vector3(1.72, 0.0, 1.80)

const M_BACK_LEFT := Vector3(-2.50, 0.0, -2.20)
const M_BACK_RIGHT := Vector3(2.50, 0.0, -2.20)
const M_FRONT_LEFT := Vector3(-3.30, 0.0, 1.80)
const M_FRONT_CENTER := Vector3(0.0, 0.0, 2.20)
const M_FRONT_RIGHT := Vector3(3.30, 0.0, 1.80)

const W_POSITIONS := {
	1: [W_BACK_CENTER],
	2: [W_FRONT_LEFT, W_FRONT_RIGHT],
	3: [W_BACK_LEFT, W_BACK_CENTER, W_BACK_RIGHT],
	4: [W_BACK_LEFT, W_BACK_RIGHT, W_FRONT_LEFT, W_FRONT_RIGHT],
	5: [W_BACK_LEFT, W_BACK_CENTER, W_BACK_RIGHT, W_FRONT_LEFT, W_FRONT_RIGHT],
}

const M_POSITIONS := {
	1: [M_FRONT_CENTER],
	2: [M_BACK_LEFT, M_BACK_RIGHT],
	3: [M_FRONT_LEFT, M_FRONT_CENTER, M_FRONT_RIGHT],
	4: [M_BACK_LEFT, M_BACK_RIGHT, M_FRONT_LEFT, M_FRONT_RIGHT],
	5: [M_BACK_LEFT, M_BACK_RIGHT, M_FRONT_LEFT, M_FRONT_CENTER, M_FRONT_RIGHT],
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
