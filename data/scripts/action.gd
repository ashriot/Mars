extends Resource
class_name Action

enum PowerType { ATTACK, PSYCHE }
enum DamageType { KINETIC, ENERGY, PIERCING }
enum TargetType {
	SELF, TEAM_MEMBER, TEAMMATE, TEAM, TEAMMATES_ONLY,
	ONE_ENEMY, ALL_ENEMIES, RANDOM_ENEMY
}

@export var action_name: String = "New Action"
@export var icon: Texture
@export_multiline var description: String = ""
@export var focus_cost: int = 0
@export var auto_target: bool = false

@export var target_type: TargetType = TargetType.ONE_ENEMY
@export var effects: Array[ActionEffect]

var is_attack: bool :
	get:
		for effect in effects:
			if effect is Effect_Damage:
				return true
		return false
