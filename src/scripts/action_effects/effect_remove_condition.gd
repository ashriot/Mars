extends ActionEffect
class_name Effect_RemoveCondition

@export var condition_name: String


func execute(attacker_node: Node, targets: Array, _battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	BattleCombatant.resolve_model(attacker_node)
	for target_node: Node in targets:
		var target := BattleCombatant.resolve_model(target_node)
		if not target.has_condition(condition_name):
			continue
		print(target.actor_name, " lost condition: ", condition_name)
		await target.remove_condition(condition_name)
