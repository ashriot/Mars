extends ActionEffect
class_name Effect_ApplyCondition

@export var condition: Condition


func execute(attacker: ActorCard, parent_targets: Array, _battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	condition.attacker = attacker
	for target in parent_targets:
		target.add_condition(condition)
