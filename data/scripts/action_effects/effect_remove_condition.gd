extends ActionEffect
class_name Effect_RemoveCondition

@export var condition_name: String
@export var remove_debuff: bool = false


func execute(_attacker: ActorCard, targets: Array, _battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	for target in targets:
		if not target.has_condition(condition_name):
			continue
		print(target.actor_name, " lost condition: ", condition_name)
		target.remove_condition(condition_name, remove_debuff)
