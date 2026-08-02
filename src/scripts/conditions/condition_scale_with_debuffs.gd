extends Condition
class_name Condition_ScaleWithDebuffs


func get_damage_dealt_modifier(attacker_node: Node, target_node: Node) -> float:
	BattleCombatant.resolve_model(attacker_node)
	var target := BattleCombatant.resolve_model(target_node)
	var debuff_count = target.count_debuffs()
	var bonus = debuff_count * damage_dealt_scalar
	bonus = min(bonus, 1.0)
	return bonus
