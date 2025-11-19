extends Condition
class_name Condition_ScaleWithDebuffs


func get_damage_dealt_scalar(_attacker: Node, target: Node) -> float:
	var debuff_count = target.count_debuffs()
	var bonus = debuff_count * damage_dealt_scalar
	bonus = min(bonus, 1.0)
	return bonus
