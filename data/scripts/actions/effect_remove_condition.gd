extends ActionEffect
class_name Effect_RemoveCondition

@export var condition: Condition


func execute(attacker: ActorCard, _primary_targets: Array, _battle_manager: BattleManager, _action: Action = null) -> void:
	attacker.remove_condition(condition)
