extends Resource
class_name Action

# Define our target enum
enum TargetType { SELF, TEAM_MEMBER, TEAMMATE, TEAM, TEAMMATES_ONLY, ONE_ENEMY, ALL_ENEMIES, ENEMY_GROUP, RANDOM_GROUP, RANDOM_ALL }

enum PowerType { ATTACK, PSYCHE }
enum DamageType { KINETIC, ENERGY, PIERCING }

@export var action_name: String
@export var icon: Texture
@export_multiline var description: String
@export var focus_cost: int = 0
@export var hit_count: int = 1
@export_range(0.0, 10.0) var potency: float = 1.0
@export var target_type: TargetType = TargetType.ONE_ENEMY
@export var power_type: PowerType = PowerType.ATTACK
@export var damage_type: DamageType = DamageType.KINETIC
# @export var status_effect: Resource # For later
