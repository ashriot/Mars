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


static func resolve_hit(
	attacker: ActorCard,
	target: ActorCard,
	power_type: Action.PowerType,
	resolved_potency: ResolvedPotency,
	distribution_count: int,
	resolved_damage_type: Action.DamageType,
	is_critical: bool,
	hit_context: DamageContext,
	request_modifier: Callable = Callable(),
) -> DamageResult:
	var base_power := attacker.get_power(power_type)
	var overload_power := 0
	if hit_context.target != null and hit_context.target.is_breached:
		overload_power = attacker.current_stats.overload
	var precision_power := attacker.get_crit_damage_bonus() if is_critical else 0
	var defense := 0
	if resolved_damage_type == Action.DamageType.KINETIC:
		defense = target.current_stats.kinetic_defense
	elif resolved_damage_type == Action.DamageType.ENERGY:
		defense = target.current_stats.energy_defense

	var request := DamageRequest.new(
		base_power,
		overload_power,
		precision_power,
		resolved_potency.potency,
		distribution_count,
		resolved_damage_type,
		defense,
		attacker.get_damage_dealt_modifier(target),
		target.get_damage_taken_modifier(attacker),
		resolved_potency.contributions,
	)
	if request_modifier.is_valid():
		request = request_modifier.call(request, hit_context) as DamageRequest
	return DamageCalculator.calculate(request)
