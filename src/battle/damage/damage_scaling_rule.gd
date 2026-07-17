class_name DamageScalingRule
extends Resource

enum Phase {
	EFFECT_START,
	CURRENT_HIT,
}

@export var phase: Phase = Phase.EFFECT_START


static func is_supported_phase(value: int) -> bool:
	return value in Phase.values()


func resolve(_base_potency: float, _context: DamageContext) -> DamageContribution:
	return DamageContribution.new(&"unused", DamageContribution.Stage.POTENCY, 0.0)


func requires_battlefield_context() -> bool:
	return false
