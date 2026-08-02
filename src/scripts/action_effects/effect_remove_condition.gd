extends ActionEffect
class_name Effect_RemoveCondition

@export var condition_name: String


func execute(_attacker: BattleCombatant, targets: Array[BattleCombatant], _battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	for target: BattleCombatant in targets:
		if not target.has_condition(condition_name):
			continue
		print(target.actor_name, " lost condition: ", condition_name)
		await target.remove_condition(condition_name)
