extends ActionEffect
class_name Effect_RemoveCondition

@export var condition_name: String


func execute(attacker: ActorCard, _primary_targets: Array, _battle_manager: BattleManager, _action: Action = null) -> void:
	print(attacker.actor_name, " lost condition: ", condition_name)
	attacker.remove_condition(condition_name)
