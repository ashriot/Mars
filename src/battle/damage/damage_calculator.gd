class_name DamageCalculator
extends RefCounted


static func calculate(request: DamageRequest) -> DamageResult:
	var effective_power := maxf(
		0.0,
		float(request.base_power + request.overload_power + request.precision_power)
			+ request.power_bonus,
	)
	var clamped_defense := 0
	if request.damage_type in [Action.DamageType.KINETIC, Action.DamageType.ENERGY]:
		clamped_defense = clampi(request.defense, 0, 90)
	var defense_multiplier := float(100 - clamped_defense) / 100.0
	var outgoing_multiplier := maxf(0.0, 1.0 + request.outgoing_modifier)
	var incoming_multiplier := maxf(0.0, 1.0 + request.incoming_modifier)
	var divisor := maxi(1, request.distribution_count)
	var raw_damage := (
		float(effective_power) * maxf(0.0, request.potency) / float(divisor)
		* defense_multiplier * outgoing_multiplier * incoming_multiplier
	)
	var final_damage := 0 if raw_damage <= 0.0 else maxi(1, floori(raw_damage))
	return DamageResult.new(
		request, effective_power, clamped_defense, defense_multiplier,
		outgoing_multiplier, incoming_multiplier, raw_damage, final_damage,
	)
