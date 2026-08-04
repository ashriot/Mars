extends RefCounted
class_name BattleFormationLayout

enum Layout { W, M }

const W_BACK_LEFT := Vector3(-5.00, 0.0, -0.21)
const W_BACK_CENTER := Vector3(0.0, 0.0, -0.61)
const W_BACK_RIGHT := Vector3(5.00, 0.0, -0.21)
const W_FRONT_LEFT := Vector3(-1.44, 0.0, 3.80)
const W_FRONT_RIGHT := Vector3(1.44, 0.0, 3.80)

const M_BACK_LEFT := Vector3(-2.70, 0.0, -0.71)
const M_BACK_RIGHT := Vector3(2.70, 0.0, -0.71)
const M_FRONT_LEFT := Vector3(-3.17, 0.0, 3.30)
const M_FRONT_CENTER := Vector3(0.0, 0.0, 3.70)
const M_FRONT_RIGHT := Vector3(3.17, 0.0, 3.30)

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
const PARTY_FOCAL_POINT := Vector3(0.0, 0.0, 9.5)


static func _party_facing_basis(position: Vector3) -> Basis:
	var direction := PARTY_FOCAL_POINT - position
	direction.y = 0.0
	if direction.is_zero_approx():
		return Basis.IDENTITY
	return Basis.looking_at(direction.normalized(), Vector3.UP, true)


static func ordinary_transforms(count: int, layout: Layout) -> Array[Transform3D]:
	if count < 0 or count > 5:
		push_error("supports at most five ordinary enemies")
		return []
	if count == 0:
		return []
	var positions: Array = W_POSITIONS[count] if layout == Layout.W else M_POSITIONS[count]
	var transforms: Array[Transform3D] = []
	for position: Vector3 in positions:
		transforms.append(Transform3D(_party_facing_basis(position), position))
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
