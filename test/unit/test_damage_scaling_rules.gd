extends GutTest


class SwarmRule extends DamageScalingRule:
	func resolve(_base_potency: float, context: DamageContext) -> DamageContribution:
		return DamageContribution.new(&"swarm", DamageContribution.Stage.POTENCY, context.other_living_allies * 0.1)


class FixedContributionRule extends DamageScalingRule:
	var contribution_source: StringName
	var contribution_stage: int
	var contribution_amount: float

	func resolve(_base_potency: float, _context: DamageContext) -> DamageContribution:
		return DamageContribution.new(
			contribution_source,
			contribution_stage as DamageContribution.Stage,
			contribution_amount,
		)


func test_flat_remaining_focus_and_guard_rules() -> void:
	var context := _context(5, 4, 2)
	var focus_rule := DamageScalingFlatPerResource.new()
	focus_rule.resource = DamageScalingFlatPerResource.ResourceType.FOCUS
	focus_rule.potency_per_point = 0.2
	var guard_rule := DamageScalingFlatPerResource.new()
	guard_rule.resource = DamageScalingFlatPerResource.ResourceType.GUARD
	guard_rule.potency_per_point = 0.25
	assert_eq(focus_rule.resolve(0.2, context).amount, 1.0)
	assert_eq(guard_rule.resolve(0.0, context).amount, 1.0)


func test_base_scalar_and_swarm_extension() -> void:
	var context := _context(5, 0, 3)
	var rule := DamageScalingBasePerResource.new()
	rule.resource = DamageScalingBasePerResource.ResourceType.FOCUS
	rule.base_scalar_per_point = 0.2
	assert_eq(rule.resolve(4.0, context).amount, 4.0)
	assert_almost_eq(SwarmRule.new().resolve(1.0, context).amount, 0.3, 0.0001)


func test_resolver_retains_labeled_breakdown() -> void:
	var rule := DamageScalingFlatPerResource.new()
	rule.resource = DamageScalingFlatPerResource.ResourceType.FOCUS
	rule.potency_per_point = 0.2
	var resolved := DamageResolver.resolve_potency(0.2, [rule], _context(5, 0, 0))
	assert_eq(resolved.potency, 1.2)
	assert_eq(resolved.contributions[0].source, &"remaining_focus")


func test_typed_contribution_stages_route_only_to_their_formula_categories() -> void:
	var rules: Array[DamageScalingRule] = [
		_fixed_rule(&"potency", DamageContribution.Stage.POTENCY, 0.5),
		_fixed_rule(&"power", DamageContribution.Stage.POWER, 20.0),
		_fixed_rule(&"outgoing", DamageContribution.Stage.OUTGOING, 0.25),
		_fixed_rule(&"incoming", DamageContribution.Stage.INCOMING, 0.2),
	]
	var context := _context(0, 0, 0)
	var resolved := DamageResolver.resolve_potency(1.0, rules, context)
	var attacker := ActorCard.new()
	attacker.current_stats = ActorStats.new()
	attacker.current_stats.attack = 100
	var target := ActorCard.new()
	target.current_stats = ActorStats.new()
	var result := DamageResolver.resolve_hit(
		attacker,
		target,
		Action.PowerType.ATTACK,
		resolved,
		1,
		Action.DamageType.PIERCING,
		false,
		context,
	)

	assert_almost_eq(result.request.potency, 1.5, 0.0001)
	assert_almost_eq(result.request.power_bonus, 20.0, 0.0001)
	assert_almost_eq(result.effective_power, 120.0, 0.0001)
	assert_almost_eq(result.request.outgoing_modifier, 0.25, 0.0001)
	assert_almost_eq(result.request.incoming_modifier, 0.2, 0.0001)
	assert_almost_eq(result.raw_damage, 270.0, 0.0001)
	assert_eq(
		result.request.contributions.map(func(value: DamageContribution): return value.source),
		[&"potency", &"power", &"outgoing", &"incoming"],
	)
	attacker.free()
	target.free()


func test_unsupported_contribution_stage_is_reported_and_excluded() -> void:
	var invalid_rule := _fixed_rule(&"invalid", 99, 10.0)
	var resolved := DamageResolver.resolve_potency(
		1.0,
		[invalid_rule],
		_context(0, 0, 0),
	)

	assert_push_error("unsupported contribution stage")
	assert_eq(resolved.potency, 1.0)
	assert_true(resolved.contributions.is_empty())


func _fixed_rule(source: StringName, stage: int, amount: float) -> FixedContributionRule:
	var rule := FixedContributionRule.new()
	rule.contribution_source = source
	rule.contribution_stage = stage
	rule.contribution_amount = amount
	return rule


func _context(focus: int, guard: int, other_living_allies: int) -> DamageContext:
	var attacker := CombatantSnapshot.new(100, focus, guard, false, false, [])
	var target := CombatantSnapshot.new(100, 0, 0, false, false, [])
	return DamageContext.new(attacker, target, other_living_allies, 0, null, null, {})
