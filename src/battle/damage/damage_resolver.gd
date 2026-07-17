class_name DamageResolver
extends RefCounted


class ResolvedPotency extends RefCounted:
	var _base_potency: float
	var _potency: float
	var _contributions: Array[DamageContribution]

	var base_potency: float:
		get: return _base_potency
	var potency: float:
		get: return _potency
	var contributions: Array[DamageContribution]:
		get: return _contributions.duplicate()


	func _init(
		resolved_base_potency: float,
		resolved_potency: float,
		resolved_contributions: Array[DamageContribution],
	) -> void:
		_base_potency = resolved_base_potency
		_potency = resolved_potency
		_contributions = resolved_contributions.duplicate()


static func resolve_potency(
	base_potency: float,
	rules: Array[DamageScalingRule],
	context: DamageContext,
) -> ResolvedPotency:
	var contributions: Array[DamageContribution] = []
	var final_potency := base_potency
	for rule in rules:
		if rule == null:
			continue
		var contribution := rule.resolve(base_potency, context)
		contributions.append(contribution)
		final_potency += contribution.amount
	return ResolvedPotency.new(base_potency, maxf(0.0, final_potency), contributions)
