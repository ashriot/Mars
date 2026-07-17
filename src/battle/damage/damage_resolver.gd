class_name DamageResolver
extends RefCounted


class ResolvedPotency extends RefCounted:
	var _base_potency: float
	var _potency: float
	var _unclamped_potency: float
	var _contributions: Array[DamageContribution]

	var base_potency: float:
		get: return _base_potency
	var potency: float:
		get: return _potency
	var unclamped_potency: float:
		get: return _unclamped_potency
	var contributions: Array[DamageContribution]:
		get: return _contributions.duplicate()


	func _init(
		resolved_base_potency: float,
		resolved_potency: float,
		resolved_contributions: Array[DamageContribution],
		resolved_unclamped_potency: float = NAN,
	) -> void:
		_base_potency = resolved_base_potency
		_potency = resolved_potency
		_unclamped_potency = resolved_potency \
			if is_nan(resolved_unclamped_potency) \
			else resolved_unclamped_potency
		_contributions = resolved_contributions.duplicate()


static func resolve_potency(
	base_potency: float,
	rules: Array[DamageScalingRule],
	context: DamageContext,
	phase: DamageScalingRule.Phase = DamageScalingRule.Phase.EFFECT_START,
) -> ResolvedPotency:
	var contributions: Array[DamageContribution] = []
	var final_potency := base_potency
	for rule in rules:
		if rule == null:
			continue
		if not DamageScalingRule.is_supported_phase(rule.phase):
			push_error("DamageResolver: unsupported scaling phase %s" % rule.phase)
			continue
		if rule.phase != phase:
			continue
		var contribution := rule.resolve(base_potency, context)
		if contribution == null:
			push_error("DamageResolver: scaling rule returned no contribution")
			continue
		if contribution.stage not in DamageContribution.Stage.values():
			push_error(
				"DamageResolver: unsupported contribution stage %s" % contribution.stage,
			)
			continue
		contributions.append(contribution)
		if contribution.stage == DamageContribution.Stage.POTENCY:
			final_potency += contribution.amount
	return ResolvedPotency.new(
		base_potency,
		maxf(0.0, final_potency),
		contributions,
		final_potency,
	)


static func combine_potency(
	base_potency: float,
	effect_start: ResolvedPotency,
	current_hit: ResolvedPotency,
) -> ResolvedPotency:
	var contributions: Array[DamageContribution] = []
	var final_potency := effect_start.unclamped_potency \
		if effect_start != null \
		else base_potency
	if effect_start != null:
		contributions.append_array(effect_start.contributions)
	if current_hit != null:
		for contribution: DamageContribution in current_hit.contributions:
			contributions.append(contribution)
			if contribution.stage == DamageContribution.Stage.POTENCY:
				final_potency += contribution.amount
	return ResolvedPotency.new(
		base_potency,
		maxf(0.0, final_potency),
		contributions,
		final_potency,
	)


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
	var was_breached := hit_context.target != null and hit_context.target.is_breached
	if was_breached:
		overload_power = attacker.current_stats.overload
	var precision_power := attacker.get_crit_damage_bonus() if is_critical else 0
	var contributions: Array[DamageContribution] = []
	contributions.assign(resolved_potency.contributions)
	contributions.append_array(attacker.get_damage_dealt_contributions(target))
	contributions.append_array(target.get_damage_taken_contributions(attacker))
	var power_bonus := _contribution_total(
		contributions,
		DamageContribution.Stage.POWER,
	)
	var outgoing_bonus := _contribution_total(
		contributions,
		DamageContribution.Stage.OUTGOING,
	)
	var incoming_bonus := _contribution_total(
		contributions,
		DamageContribution.Stage.INCOMING,
	)
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
		outgoing_bonus,
		incoming_bonus,
		contributions,
		power_bonus,
		resolved_potency.base_potency,
	)
	if request_modifier.is_valid():
		request = request_modifier.call(request, hit_context) as DamageRequest
	return DamageResult.with_hit_facts(
		DamageCalculator.calculate(request),
		is_critical,
		was_breached,
		hit_context.source_effect,
		hit_context.source_action,
	)


static func _contribution_total(
	contributions: Array[DamageContribution],
	stage: DamageContribution.Stage,
) -> float:
	var total := 0.0
	for contribution: DamageContribution in contributions:
		if contribution.stage == stage:
			total += contribution.amount
	return total
