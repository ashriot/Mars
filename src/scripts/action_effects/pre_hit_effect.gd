extends Resource
class_name PreHitEffect

func execute(_context: Dictionary, attacker_node: Node, target_node: Node) -> void:
	BattleCombatant.resolve_model(attacker_node)
	BattleCombatant.resolve_model(target_node)
	pass
