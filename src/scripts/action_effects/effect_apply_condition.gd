extends ActionEffect
class_name Effect_ApplyCondition

@export var condition: Condition


func execute(attacker_node: Node, parent_targets: Array, _battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	var attacker := BattleCombatant.resolve_model(attacker_node)
	condition.attacker = attacker
	for target_node: Node in parent_targets:
		var target := BattleCombatant.resolve_model(target_node)
		await target.add_condition(condition)
