extends ActionEffect
class_name Effect_ApplyCondition

@export var condition: Condition


func execute(_attacker: ActorCard, parent_targets: Array, _battle_manager: BattleManager, _action: Action = null) -> void:
	for target in parent_targets:
		target.add_condition(condition)
