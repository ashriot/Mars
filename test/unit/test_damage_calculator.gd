extends GutTest


func test_plain_defended_and_critical_power() -> void:
	var normal := DamageCalculator.calculate(_request(200, 0, 0, 0.5, 1, Action.DamageType.KINETIC, 50))
	var critical := DamageCalculator.calculate(_request(200, 0, 400, 0.5, 1, Action.DamageType.KINETIC, 50))
	assert_eq(normal.final_damage, 50)
	assert_eq(critical.final_damage, 150)
	assert_eq(critical.effective_power, 600)


func test_ovr_is_universal_for_attack_psyche_and_piercing() -> void:
	for damage_type in [Action.DamageType.KINETIC, Action.DamageType.ENERGY, Action.DamageType.PIERCING]:
		var result := DamageCalculator.calculate(_request(100, 75, 0, 1.0, 1, damage_type, 0))
		assert_eq(result.effective_power, 175)
		assert_eq(result.final_damage, 175)


func test_defense_clamps_and_piercing_bypasses() -> void:
	assert_eq(DamageCalculator.calculate(_request(100, 0, 0, 1.0, 1, Action.DamageType.KINETIC, -20)).final_damage, 100)
	assert_eq(DamageCalculator.calculate(_request(100, 0, 0, 1.0, 1, Action.DamageType.KINETIC, 90)).final_damage, 10)
	assert_eq(DamageCalculator.calculate(_request(100, 0, 0, 1.0, 1, Action.DamageType.KINETIC, 180)).final_damage, 10)
	assert_eq(DamageCalculator.calculate(_request(100, 0, 0, 1.0, 1, Action.DamageType.PIERCING, 90)).final_damage, 100)


func test_modifiers_split_floor_and_positive_minimum() -> void:
	var stacked := DamageCalculator.calculate(_request(100, 0, 0, 1.0, 1, Action.DamageType.PIERCING, 0, 0.5, 0.2))
	var split := DamageCalculator.calculate(_request(100, 0, 0, 1.0, 3, Action.DamageType.PIERCING, 0))
	var minimum := DamageCalculator.calculate(_request(1, 0, 0, 0.2, 1, Action.DamageType.KINETIC, 90))
	var zero := DamageCalculator.calculate(_request(100, 0, 0, 0.0, 1, Action.DamageType.PIERCING, 0))
	assert_eq(stacked.final_damage, 180)
	assert_eq(split.final_damage, 33)
	assert_eq(minimum.final_damage, 1)
	assert_eq(zero.final_damage, 0)


func _request(
	base_power: int,
	overload_power: int,
	precision_power: int,
	potency: float,
	distribution_count: int,
	damage_type: Action.DamageType,
	defense: int,
	outgoing_modifier: float = 0.0,
	incoming_modifier: float = 0.0,
) -> DamageRequest:
	return DamageRequest.new(
		base_power, overload_power, precision_power, potency,
		distribution_count, damage_type, defense,
		outgoing_modifier, incoming_modifier, [],
	)
