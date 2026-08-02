extends PreHitEffect
class_name PreHitEffect_ModifyAttackerStats

@export var aim_bonus: int = 0

func execute(context: Dictionary, attacker_node: Node, target_node: Node) -> void:
	BattleCombatant.resolve_model(attacker_node)
	BattleCombatant.resolve_model(target_node)
	context.get_or_add("aim_bonus", aim_bonus)
	print("PreHit: Added ", aim_bonus, " aim")
