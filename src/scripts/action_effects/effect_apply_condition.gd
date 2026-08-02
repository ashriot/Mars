extends ActionEffect
class_name Effect_ApplyCondition

@export var condition: Condition


func execute(attacker_node: Node, parent_targets: Array, _battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	var attacker := BattleCombatant.resolve_model(attacker_node)
	var targets := BattleCombatant.resolve_models(parent_targets)
	condition.attacker = attacker
	for target: BattleCombatant in targets:
		await target.add_condition(condition)
