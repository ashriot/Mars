extends PreHitEffect
class_name PreHitEffect_ModifyAttackerStats

@export var aim_bonus: int = 0
@export var damage_bonus: float = 0.0

func execute(context: Dictionary, _attacker: ActorCard, _target: ActorCard) -> void:
	context.get_or_add("aim_bonus", aim_bonus)
	context.get_or_add("damage_bonus", damage_bonus)
	print("PreHit: Added ", aim_bonus, " aim")
