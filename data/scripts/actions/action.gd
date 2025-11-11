# Action.gd
extends Resource
class_name Action

enum TargetType {
	SELF, TEAM_MEMBER, TEAMMATE, TEAM, TEAMMATES_ONLY,
	ONE_ENEMY, ALL_ENEMIES, ENEMY_GROUP, RANDOM_GROUP, RANDOM_ALL
}
# (We'll keep these here so Effect scripts can reference them)
enum PowerType { ATTACK, PSYCHE }
enum DamageType { KINETIC, ENERGY, PIERCING }

# --- "Button" Data (What the player sees) ---
@export var action_name: String = "New Action"
@export var icon: Texture
@export_multiline var description: String = ""
@export var focus_cost: int = 1
@export var auto_target: bool = false

# --- "Logic" Data (What the BattleManager uses) ---
@export var target_type: TargetType = TargetType.ONE_ENEMY

@export var effects: Array[ActionEffect]
