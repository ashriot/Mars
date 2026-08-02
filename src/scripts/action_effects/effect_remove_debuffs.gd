extends Effect_RemoveCondition
class_name Effect_RemoveDebuffs

@export var quantity: int = 1


func execute(attacker_node: Node, targets: Array, _battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	BattleCombatant.resolve_model(attacker_node)
	for target_node: Node in targets:
		var target := BattleCombatant.resolve_model(target_node)
		await target.remove_debuffs(quantity)
