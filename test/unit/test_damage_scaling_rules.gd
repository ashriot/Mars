extends GutTest


class SwarmRule extends DamageScalingRule:
	func resolve(_base_potency: float, context: DamageContext) -> DamageContribution:
		return DamageContribution.new(&"swarm", DamageContribution.Stage.POTENCY, context.other_living_allies * 0.1)


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


func _context(focus: int, guard: int, other_living_allies: int) -> DamageContext:
	var attacker := CombatantSnapshot.new(100, focus, guard, false, false, [])
	var target := CombatantSnapshot.new(100, 0, 0, false, false, [])
	return DamageContext.new(attacker, target, other_living_allies, 0, null, null, {})
