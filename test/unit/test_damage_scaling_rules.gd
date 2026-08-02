extends GutTest

const CardTestFactory := preload("res://test/helpers/card_test_factory.gd")


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


class FixedModifierTrait extends Trait:
	var outgoing_modifier: float
	var incoming_modifier: float

	func get_damage_dealt_modifier(_target: Node) -> float:
		return outgoing_modifier

	func get_damage_taken_modifier(_attacker: Node) -> float:
		return incoming_modifier


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


func test_flat_rule_can_read_target_focus_without_changing_attacker_default() -> void:
	var attacker := CombatantSnapshot.new(100, 2, 3, false, false, [])
	var target := CombatantSnapshot.new(100, 5, 7, false, false, [])
	var context := DamageContext.new(attacker, target, 0, 0, null, null, {})
	var attacker_rule := DamageScalingFlatPerResource.new()
	attacker_rule.resource = DamageScalingFlatPerResource.ResourceType.FOCUS
	attacker_rule.potency_per_point = 0.15
	var target_rule := DamageScalingFlatPerResource.new()
	target_rule.resource_owner = DamageScalingFlatPerResource.ResourceOwner.TARGET
	target_rule.resource = DamageScalingFlatPerResource.ResourceType.FOCUS
	target_rule.potency_per_point = 0.15
	assert_almost_eq(attacker_rule.resolve(0.3, context).amount, 0.3, 0.0001)
	assert_eq(attacker_rule.resolve(0.3, context).source, &"remaining_focus")
	assert_almost_eq(target_rule.resolve(0.3, context).amount, 0.75, 0.0001)
	assert_eq(target_rule.resolve(0.3, context).source, &"target_focus")


func test_base_rule_can_read_target_guard() -> void:
	var attacker := CombatantSnapshot.new(100, 0, 1, false, false, [])
	var target := CombatantSnapshot.new(100, 0, 6, false, false, [])
	var context := DamageContext.new(attacker, target, 0, 0, null, null, {})
	var rule := DamageScalingBasePerResource.new()
	rule.resource_owner = DamageScalingBasePerResource.ResourceOwner.TARGET
	rule.resource = DamageScalingBasePerResource.ResourceType.GUARD
	rule.base_scalar_per_point = 0.25
	assert_almost_eq(rule.resolve(1.0, context).amount, 1.5, 0.0001)
	assert_eq(rule.resolve(1.0, context).source, &"target_guard")


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
	var attacker := CardTestFactory.actor()
	attacker.current_stats = ActorStats.new()
	attacker.current_stats.attack = 100
	var target := CardTestFactory.actor(BattleCombatant.Faction.ENEMY)
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


func test_request_retains_authored_potency_and_labeled_actor_modifiers() -> void:
	var scaling_rule := _fixed_rule(
		&"rule_outgoing", DamageContribution.Stage.OUTGOING, 0.05,
	)
	var resolved := DamageResolver.resolve_potency(
		0.8, [scaling_rule], _context(0, 0, 0),
	)
	var attacker := CardTestFactory.actor()
	attacker.current_stats = ActorStats.new()
	attacker.current_stats.attack = 100
	var focus_condition := Condition.new()
	focus_condition.condition_name = "Battle Focus"
	focus_condition.damage_dealt_scalar = 0.1
	var sharpshooter := FixedModifierTrait.new()
	sharpshooter.trait_name = "Sharpshooter"
	sharpshooter.outgoing_modifier = 0.2
	attacker.active_conditions = [focus_condition]
	attacker.active_traits = [sharpshooter]
	var target := CardTestFactory.actor(BattleCombatant.Faction.ENEMY)
	target.current_stats = ActorStats.new()
	var exposed_condition := Condition.new()
	exposed_condition.condition_name = "Exposed Armor"
	exposed_condition.damage_taken_scalar = 0.3
	var fragile_frame := FixedModifierTrait.new()
	fragile_frame.trait_name = "Fragile Frame"
	fragile_frame.incoming_modifier = 0.4
	target.active_conditions = [exposed_condition]
	target.active_traits = [fragile_frame]

	var result := DamageResolver.resolve_hit(
		attacker,
		target,
		Action.PowerType.ATTACK,
		resolved,
		1,
		Action.DamageType.PIERCING,
		false,
		_context(0, 0, 0),
	)
	var contributions := result.request.contributions

	assert_almost_eq(result.request.base_potency, 0.8, 0.0001)
	_assert_contribution_once(
		contributions, &"rule_outgoing", DamageContribution.Stage.OUTGOING, 0.05,
	)
	_assert_contribution_once(
		contributions, &"condition_battle_focus", DamageContribution.Stage.OUTGOING, 0.1,
	)
	_assert_contribution_once(
		contributions, &"trait_sharpshooter", DamageContribution.Stage.OUTGOING, 0.2,
	)
	_assert_contribution_once(
		contributions, &"condition_exposed_armor", DamageContribution.Stage.INCOMING, 0.3,
	)
	_assert_contribution_once(
		contributions, &"trait_fragile_frame", DamageContribution.Stage.INCOMING, 0.4,
	)
	assert_almost_eq(
		result.request.outgoing_modifier,
		_contribution_sum(contributions, DamageContribution.Stage.OUTGOING),
		0.0001,
	)
	assert_almost_eq(
		result.request.incoming_modifier,
		_contribution_sum(contributions, DamageContribution.Stage.INCOMING),
		0.0001,
	)
	attacker.free()
	target.free()


func test_source_power_bonus_reads_condition_creator_psy() -> void:
	var condition := ConditionSourcePowerBonus.new()
	condition.power_type = Action.PowerType.PSYCHE
	condition.power_scalar = 1.0
	condition.attacker = _actor_with_power(Action.PowerType.PSYCHE, 40)
	var attacking_recipient := _actor_with_power(Action.PowerType.PSYCHE, 5)

	assert_eq(condition.get_damage_dealt_power_bonus(attacking_recipient, null), 40.0)

	condition.attacker.free()
	attacking_recipient.free()


func test_source_power_bonus_returns_zero_without_a_valid_creator() -> void:
	var condition := ConditionSourcePowerBonus.new()
	condition.power_type = Action.PowerType.PSYCHE
	condition.power_scalar = 1.0

	assert_eq(condition.get_damage_dealt_power_bonus(null, null), 0.0)


func test_source_power_contribution_preserves_outgoing_contribution() -> void:
	var attacker := _actor_with_power(Action.PowerType.ATTACK, 100)
	var source := _actor_with_power(Action.PowerType.PSYCHE, 40)
	var condition := ConditionSourcePowerBonus.new()
	condition.condition_name = "Source Psy"
	condition.power_type = Action.PowerType.PSYCHE
	condition.power_scalar = 1.0
	condition.damage_dealt_scalar = 0.25
	condition.attacker = source
	attacker.active_conditions = [condition]
	var target := _actor_with_power(Action.PowerType.ATTACK, 0)
	var context := _context(0, 0, 0)
	var resolved := DamageResolver.resolve_potency(1.0, [], context)

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

	_assert_contribution_once(
		result.request.contributions,
		&"condition_source_psy",
		DamageContribution.Stage.POWER,
		40.0,
	)
	_assert_contribution_once(
		result.request.contributions,
		&"condition_source_psy",
		DamageContribution.Stage.OUTGOING,
		0.25,
	)
	assert_almost_eq(attacker.get_damage_dealt_modifier(target), 0.25, 0.0001)
	attacker.free()
	source.free()
	target.free()


func test_source_power_bonus_composes_for_combatants() -> void:
	var attacker := _combatant_with_power(Action.PowerType.ATTACK, 100)
	var source := _combatant_with_power(Action.PowerType.PSYCHE, 40)
	var condition := ConditionSourcePowerBonus.new()
	condition.condition_name = "Source Psy"
	condition.power_type = Action.PowerType.PSYCHE
	condition.power_scalar = 1.0
	condition.damage_dealt_scalar = 0.25
	condition.attacker = source
	attacker.active_conditions = [condition]
	var target := _combatant_with_power(Action.PowerType.ATTACK, 0)

	var contributions := attacker.get_damage_dealt_contributions(target)

	_assert_contribution_once(
		contributions,
		&"condition_source_psy",
		DamageContribution.Stage.POWER,
		40.0,
	)
	_assert_contribution_once(
		contributions,
		&"condition_source_psy",
		DamageContribution.Stage.OUTGOING,
		0.25,
	)
	attacker.free()
	source.free()
	target.free()


func test_distribution_divides_entire_source_power_bonus() -> void:
	var attacker := _actor_with_power(Action.PowerType.ATTACK, 100)
	var source := _actor_with_power(Action.PowerType.PSYCHE, 40)
	var condition := ConditionSourcePowerBonus.new()
	condition.power_type = Action.PowerType.PSYCHE
	condition.power_scalar = 1.0
	condition.attacker = source
	attacker.active_conditions = [condition]
	var target := _actor_with_power(Action.PowerType.ATTACK, 0)
	var context := _context(0, 0, 0)
	var resolved := DamageResolver.resolve_potency(1.0, [], context)

	var result := DamageResolver.resolve_hit(
		attacker,
		target,
		Action.PowerType.ATTACK,
		resolved,
		2,
		Action.DamageType.PIERCING,
		false,
		context,
	)

	assert_almost_eq(result.effective_power, 140.0, 0.0001)
	assert_almost_eq(result.raw_damage, 70.0, 0.0001)
	attacker.free()
	source.free()
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


func _assert_contribution_once(
	contributions: Array[DamageContribution],
	source: StringName,
	stage: DamageContribution.Stage,
	amount: float,
) -> void:
	var matches := contributions.filter(func(contribution: DamageContribution) -> bool:
		return contribution.source == source and contribution.stage == stage
	)
	assert_eq(matches.size(), 1, "%s appears exactly once" % source)
	if matches.size() == 1:
		assert_almost_eq(matches[0].amount, amount, 0.0001)


func _contribution_sum(
	contributions: Array[DamageContribution],
	stage: DamageContribution.Stage,
) -> float:
	var total := 0.0
	for contribution: DamageContribution in contributions:
		if contribution.stage == stage:
			total += contribution.amount
	return total


func _context(focus: int, guard: int, other_living_allies: int) -> DamageContext:
	var attacker := CombatantSnapshot.new(100, focus, guard, false, false, [])
	var target := CombatantSnapshot.new(100, 0, 0, false, false, [])
	return DamageContext.new(attacker, target, other_living_allies, 0, null, null, {})


func _actor_with_power(power_type: Action.PowerType, value: int) -> ActorCard:
	var actor := CardTestFactory.actor()
	actor.current_stats = ActorStats.new()
	if power_type == Action.PowerType.ATTACK:
		actor.current_stats.attack = value
	elif power_type == Action.PowerType.PSYCHE:
		actor.current_stats.psyche = value
	return actor


func _combatant_with_power(
	power_type: Action.PowerType,
	value: int,
) -> BattleCombatant:
	var stats := ActorStats.new()
	if power_type == Action.PowerType.ATTACK:
		stats.attack = value
	elif power_type == Action.PowerType.PSYCHE:
		stats.psyche = value
	var combatant := BattleCombatant.new()
	combatant.setup_base(stats, BattleCombatant.Faction.HERO)
	return combatant
