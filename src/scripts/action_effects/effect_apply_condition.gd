extends ActionEffect
class_name Effect_ApplyCondition

@export var condition: Condition


func execute(attacker: BattleCombatant, targets: Array[BattleCombatant], _battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	condition.attacker = attacker
	for target: BattleCombatant in targets:
		await target.add_condition(condition)
