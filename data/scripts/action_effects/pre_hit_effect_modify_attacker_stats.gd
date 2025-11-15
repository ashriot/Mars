extends PreHitEffect
class_name PreHitEffect_ModifyAttackerStats

@export var precision_bonus: int = 0
@export var damage_bonus: float = 0.0

func execute(context: Dictionary, _attacker: ActorCard, _target: ActorCard) -> void:
	context.precision_bonus += precision_bonus
	context.damage_bonus += damage_bonus
	print("PreHit: Added ", precision_bonus, " Precision")
