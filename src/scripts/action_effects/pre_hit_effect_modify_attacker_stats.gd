extends PreHitEffect
class_name PreHitEffect_ModifyAttackerStats

@export var aim_bonus: int = 0

func execute(context: Dictionary, _attacker: Node, _target: Node) -> void:
	context.get_or_add("aim_bonus", aim_bonus)
	print("PreHit: Added ", aim_bonus, " aim")
