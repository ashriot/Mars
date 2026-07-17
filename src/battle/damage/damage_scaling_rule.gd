class_name DamageScalingRule
extends Resource


func resolve(_base_potency: float, _context: DamageContext) -> DamageContribution:
	return DamageContribution.new(&"unused", DamageContribution.Stage.POTENCY, 0.0)
