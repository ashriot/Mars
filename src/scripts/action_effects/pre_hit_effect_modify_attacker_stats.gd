extends PreHitEffect
class_name PreHitEffect_ModifyAttackerStats

@export var aim_dmg: int = 0
@export var damage_bonus: float = 0.0

func execute(context: Dictionary, _attacker: ActorCard, _target: ActorCard) -> void:
	context.get_or_add("aim_dmg", aim_dmg)
	context.get_or_add("damage_bonus", damage_bonus)
	print("PreHit: Added ", aim_dmg, " aim")
