# Effect_Damage.gd
extends ActionEffect
class_name Effect_Damage


class DamageTypeDecision extends RefCounted:
	var resolved_damage_type: Action.DamageType
	var forced_damage_type: Action.DamageType
	var condition_to_consume: Condition


	func _init(
		resolved_type: Action.DamageType,
		forced_type: Action.DamageType,
		consumable_condition: Condition,
	) -> void:
		resolved_damage_type = resolved_type
		forced_damage_type = forced_type
		condition_to_consume = consumable_condition


# --- Base Damage Properties ---
@export var potency: float = 1.0
@export var hit_count: int = 1
@export var split_damage: bool = false
@export var is_indirect: bool = false
@export var power_type: Action.PowerType = Action.PowerType.ATTACK
@export var damage_type: Action.DamageType = Action.DamageType.KINETIC

@export var scaling_rules: Array[DamageScalingRule] = []
@export var lifedrain_scalar: float = 0.0
@export var on_hit_triggers: Array[HitTrigger]
@export var pre_hit_triggers: Array[PreHitTrigger]


func get_presentation(context: EffectPresentationContext) -> EffectPresentation:
	if not context.is_complete or context.targets.is_empty():
		return _get_authored_presentation(context)
	var sequence := DamagePreview.for_plan(
		self,
		context.actor,
		context.targets,
		context.action,
		context.critical,
		context.battle_manager,
	)
	var sequence_results: Array[DamageResult] = []
	if sequence != null:
		sequence_results.assign(sequence.results)
	if not sequence.is_complete or sequence_results.is_empty():
		return _get_authored_presentation(context)
	var result := sequence_results[0]
	var contributions := _get_sequence_contributions(sequence_results)
	var contextual_scaling := _get_contextual_scaling_text(contributions)
	var split_behavior := ""
	var sequence_bindings := _get_sequence_bindings(sequence)
	var amount: Variant = sequence_bindings.amount
	var amount_qualifier: String = sequence_bindings.amount_qualifier
	var damage_type_icon: String = sequence_bindings.damage_type
	var hit_count_text: String = sequence_bindings.hit_count_text
	if split_damage:
		if _is_group_target_action(context.action):
			split_behavior = " split across %d targets" % sequence.target_count
			if hit_count > 1:
				split_behavior += " and %d hits each" % hit_count
		else:
			split_behavior = " split across %d hits" % sequence.distribution_count
	var bindings := {
		"amount": amount,
		"amount_qualifier": amount_qualifier,
		"selected_power": result.request.base_power,
		"damage_type": damage_type_icon,
		"hit_count": hit_count,
		"hit_count_text": hit_count_text,
		"split_behavior": split_behavior,
		"contextual_scaling": contextual_scaling,
		"is_exact": true,
	}
	var details: Array[String] = [
		"Selected power: %d" % result.request.base_power,
		"Resolved potency: %s%%" % _format_percent(result.request.potency),
	]
	for contribution: DamageContribution in contributions:
		details.append(_get_contribution_detail(contribution))
	return _new_damage_presentation(bindings, details)


func _get_authored_presentation(
	context: EffectPresentationContext,
) -> EffectPresentation:
	var resolved_hit_count := _resolve_hit_count(context.actor)
	var split_behavior := ""
	var amount_qualifier := ""
	var hit_count_text := "x%d" % resolved_hit_count \
		if resolved_hit_count > 1 else ""
	if split_damage:
		hit_count_text = ""
		amount_qualifier = " total"
		if _has_unavailable_group_distribution(context):
			split_behavior = " split across all targets"
			if resolved_hit_count > 1:
				split_behavior += " and %d hits" % resolved_hit_count
		else:
			split_behavior = " split across %d hits" % maxi(
			1, context.distribution_count,
		)
	var selected_power := context.actor.get_power(power_type) \
		if context.actor != null and context.actor.current_stats != null else 0
	var bindings := {
		"amount": "%s%% %s" % [
			_format_percent(potency), _get_power_label(power_type),
		],
		"amount_qualifier": amount_qualifier,
		"selected_power": selected_power,
		"damage_type": _get_damage_type_icon(damage_type),
		"hit_count": resolved_hit_count,
		"hit_count_text": hit_count_text,
		"split_behavior": split_behavior,
		"contextual_scaling": " (includes contextual scaling)" \
			if not scaling_rules.is_empty() else "",
		"is_exact": false,
	}
	var details: Array[String] = [
		"Selected power: %d" % selected_power,
		"Authored potency: %s%%" % _format_percent(potency),
		"Exact damage unavailable until targets are known",
	]
	return _new_damage_presentation(bindings, details)


func _new_damage_presentation(
	bindings: Dictionary,
	details: Array[String],
) -> EffectPresentation:
	return EffectPresentation.new(
		"Deals {amount}{amount_qualifier}{hit_count_text} {damage_type} damage"
			+ "{split_behavior}{contextual_scaling}.",
		bindings,
		details,
	)


func _get_sequence_bindings(
	sequence: DamagePreview.Sequence,
	icon_size: int = 24,
) -> Dictionary:
	var results := sequence.results
	if results.is_empty():
		return {
			"amount": "",
			"amount_qualifier": "",
			"damage_type": "",
			"hit_count_text": "",
		}
	if sequence.is_ordered and _sequence_results_are_identical(results):
		return {
			"amount": results[0].final_damage,
			"amount_qualifier": "",
			"damage_type": _get_damage_type_icon(
				results[0].request.damage_type, icon_size,
			),
			"hit_count_text": "x%d" % results.size() if results.size() > 1 else "",
		}
	if not sequence.is_ordered:
		return _get_unordered_sequence_bindings(results, icon_size)
	var segments: Array[String] = []
	for result: DamageResult in results:
		segments.append(
			"%d %s" % [
				result.final_damage,
				_get_damage_type_icon(result.request.damage_type, icon_size),
			],
		)
	return {
		"amount": " → ".join(segments),
		"amount_qualifier": "",
		"damage_type": "",
		"hit_count_text": "",
	}


func _get_unordered_sequence_bindings(
	results: Array[DamageResult],
	icon_size: int,
) -> Dictionary:
	var values_by_type: Dictionary = {}
	for result: DamageResult in results:
		var resolved_type := result.request.damage_type
		var values: Array = values_by_type.get(resolved_type, [])
		values.append(result.final_damage)
		values_by_type[resolved_type] = values
	var resolved_types := values_by_type.keys()
	resolved_types.sort()
	if resolved_types.size() == 1:
		var resolved_type: Action.DamageType = resolved_types[0]
		return {
			"amount": _format_damage_range(values_by_type[resolved_type]),
			"amount_qualifier": " per target",
			"damage_type": _get_damage_type_icon(resolved_type, icon_size),
			"hit_count_text": "",
		}
	var segments: Array[String] = []
	for resolved_type: Action.DamageType in resolved_types:
		segments.append("%s %s" % [
			_format_damage_range(values_by_type[resolved_type]),
			_get_damage_type_icon(resolved_type, icon_size),
		])
	return {
		"amount": " / ".join(segments),
		"amount_qualifier": " per target",
		"damage_type": "",
		"hit_count_text": "",
	}


func _format_damage_range(values: Array) -> String:
	values.sort()
	if values.is_empty():
		return ""
	if values[0] == values[-1]:
		return str(values[0])
	return "%d-%d" % [values[0], values[-1]]


func _sequence_results_are_identical(results: Array[DamageResult]) -> bool:
	if results.is_empty():
		return false
	var first := results[0]
	for result: DamageResult in results:
		if result.final_damage != first.final_damage \
			or result.request.damage_type != first.request.damage_type:
			return false
	return true


func _has_unavailable_group_distribution(context: EffectPresentationContext) -> bool:
	return not context.is_complete and _is_group_target_action(context.action)


func _is_group_target_action(action: Action) -> bool:
	return action != null and action.target_type in [
			Action.TargetType.ALL_ENEMIES,
			Action.TargetType.ENEMY_GROUP,
			Action.TargetType.ALL_ALLIES,
			Action.TargetType.ALLIES_ONLY,
		]


func _get_damage_type_icon(
	resolved_damage_type: Action.DamageType,
	size: int = 24,
) -> String:
	match resolved_damage_type:
		Action.DamageType.KINETIC:
			return Action._get_bbcode_icon("kinetic", size)
		Action.DamageType.ENERGY:
			return Action._get_bbcode_icon("energy", size)
		Action.DamageType.PIERCING:
			return Action._get_bbcode_icon("pierce", size)
	return ""


func _get_power_label(resolved_power_type: Action.PowerType) -> String:
	return "PSY" if resolved_power_type == Action.PowerType.PSYCHE else "ATK"


func _get_sequence_contributions(
	results: Array[DamageResult],
) -> Array[DamageContribution]:
	var contributions: Array[DamageContribution] = []
	var seen: Dictionary = {}
	for result: DamageResult in results:
		for contribution: DamageContribution in result.request.contributions:
			var key := "%s:%d:%s" % [
				contribution.source,
				contribution.stage,
				contribution.amount,
			]
			if seen.has(key):
				continue
			seen[key] = true
			contributions.append(contribution)
	return contributions


func _get_contextual_scaling_text(contributions: Array[DamageContribution]) -> String:
	if contributions.is_empty():
		return ""
	var labels: Array[String] = []
	for contribution: DamageContribution in contributions:
		labels.append(_get_contribution_label(contribution.source))
	return " (includes contextual scaling from %s)" % ", ".join(labels)


func _get_contribution_label(source: StringName) -> String:
	match source:
		&"remaining_focus":
			return "remaining Focus after paying the cost"
		&"current_guard":
			return "current Guard"
		&"target_focus":
			return "target Focus"
		&"target_guard":
			return "target Guard"
	return str(source).replace("_", " ")


func _get_contribution_detail(contribution: DamageContribution) -> String:
	var label := _get_contribution_label(contribution.source)
	match contribution.stage:
		DamageContribution.Stage.POTENCY:
			return "%s: %s%% potency" % [
				label, _format_percent(contribution.amount),
			]
		DamageContribution.Stage.POWER:
			return "%s: %s power" % [
				label, _format_number(contribution.amount),
			]
		DamageContribution.Stage.OUTGOING:
			return "%s: %s%% outgoing damage" % [
				label, _format_percent(contribution.amount),
			]
		DamageContribution.Stage.INCOMING:
			return "%s: %s%% incoming damage" % [
				label, _format_percent(contribution.amount),
			]
	return "%s: %s" % [label, _format_number(contribution.amount)]


func _format_percent(value: float) -> String:
	return _format_number(value * 100.0)


func _format_number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) \
		else "%.1f" % value


func execute(
	attacker_node: Node,
	parent_targets: Array,
	battle_manager: BattleManager,
	action: Action = null,
	context: Dictionary = {},
) -> void:
	var attacker := BattleCombatant.resolve_model(attacker_node)
	var targets := BattleCombatant.resolve_models(parent_targets)
	var resolved_hit_count := _resolve_hit_count(attacker, context)
	var plan := _build_hit_plan(targets, action, resolved_hit_count)
	var source_action := _resolve_source_action(action, context)
	var effect_context := DamageContext.capture(
		attacker, null, battle_manager, source_action, self, context,
	)
	var resolved_potency := _resolve_potency(effect_context)
	print("\n--- Damage Effect for ", plan.planned_hit_count, " hit(s) ---")
	print("Final Potency: ", resolved_potency.potency)
	var after_attack_fired: Dictionary = {}

	for hit_index in plan.planned_hit_count:
		if battle_manager.current_state == BattleManager.State.BATTLE_OVER:
			return
		if attacker.is_defeated:
			return
		var target := _resolve_planned_target(plan, hit_index, battle_manager)
		if target == null:
			if plan.target_mode == DamageHitPlan.TargetMode.RANDOM:
				break
			continue
		if not _can_continue_hit(attacker, target, battle_manager):
			continue

		await _execute_one_hit(
			attacker,
			target,
			battle_manager,
			source_action,
			context,
			plan,
			resolved_potency,
		)

		if _should_wait_between_hits(plan, hit_index, target):
			await battle_manager.wait(0.15)
			if battle_manager.current_state == BattleManager.State.BATTLE_OVER:
				return
			if attacker.is_defeated:
				return

		if plan.target_mode != DamageHitPlan.TargetMode.RANDOM \
			and not after_attack_fired.has(target) \
			and _is_target_sequence_complete(plan, hit_index, target):
			after_attack_fired[target] = true
			await target._fire_condition_event(
				Trigger.TriggerType.AFTER_BEING_ATTACKED, context,
			)


func _build_hit_plan(
	parent_targets: Array,
	action: Action = null,
	resolved_hit_count: int = -1,
) -> DamageHitPlan:
	var hits := hit_count if resolved_hit_count < 0 else resolved_hit_count
	if action != null and action.target_type == Action.TargetType.RANDOM_ENEMY:
		return DamageHitPlan.random_targets(parent_targets, hits, split_damage)
	if parent_targets.size() == 1:
		return DamageHitPlan.single_target(parent_targets[0], hits, split_damage)
	if hits <= 1:
		return DamageHitPlan.all_targets(parent_targets, split_damage)
	var expanded_targets: Array = []
	for target in parent_targets:
		for _hit_index in hits:
			expanded_targets.append(target)
	return DamageHitPlan.all_targets(expanded_targets, split_damage)


func _resolve_hit_count(_attacker: BattleCombatant, _context: Dictionary = {}) -> int:
	return hit_count


func _resolve_planned_target(
	plan: DamageHitPlan,
	hit_index: int,
	battle_manager: BattleManager,
) -> BattleCombatant:
	var plan_candidates := plan.candidates
	if plan.target_mode == DamageHitPlan.TargetMode.RANDOM:
		return _pick_random_target(
			_filter_valid_targets(plan_candidates), battle_manager,
		)
	if plan_candidates.is_empty():
		return null
	if plan.target_mode == DamageHitPlan.TargetMode.SINGLE:
		return plan_candidates[0] as BattleCombatant
	if hit_index >= plan_candidates.size():
		return null
	return plan_candidates[hit_index] as BattleCombatant


func _can_continue_hit(
	attacker: BattleCombatant,
	target: BattleCombatant,
	battle_manager: BattleManager,
) -> bool:
	return battle_manager.current_state != BattleManager.State.BATTLE_OVER \
		and not attacker.is_defeated \
		and is_instance_valid(target) \
		and not target.is_defeated


func _execute_one_hit(
	attacker: BattleCombatant,
	target: BattleCombatant,
	battle_manager: BattleManager,
	source_action: Action,
	context: Dictionary,
	plan: DamageHitPlan,
	resolved_potency: DamageResolver.ResolvedPotency,
) -> void:
	var pre_hit_context := _get_pre_hit_triggers(attacker, target)
	var forced_damage_type := await _resolve_forced_damage_type(
		attacker, target, pre_hit_context,
	)
	var resolved_damage_type := damage_type \
		if forced_damage_type == Action.DamageType.NONE \
		else forced_damage_type
	await _apply_guard_behavior(target, resolved_damage_type)

	var hit_context := DamageContext.capture(
		attacker, target, battle_manager, source_action, self, context,
	)
	var hit_potency := _resolve_current_hit_potency(resolved_potency, hit_context)
	var crit_chance := attacker.get_aim() + target.get_incoming_aim_mods()
	crit_chance += int(pre_hit_context.get("aim_bonus", 0))
	var is_critical := _roll_percent(
		clampi(crit_chance, 0, 100), battle_manager,
	)
	var result := DamageResolver.resolve_hit(
		attacker,
		target,
		power_type,
		hit_potency,
		plan.distribution_count,
		resolved_damage_type,
		is_critical,
		hit_context,
		Callable(self, "_modify_damage_request"),
	)

	_play_hit_audio()
	var actual_damage := await _apply_calculated_hit(
		target, result, attacker, resolved_damage_type, is_critical,
	)
	var hit_event_context := context.duplicate()
	hit_event_context.merge({
		"attacker": attacker,
		"target": target,
		"targets": [target],
		"damage_result": result,
		"attempted_damage": result.final_damage,
		"actual_damage": actual_damage,
		"resolved_damage_type": resolved_damage_type,
		"is_critical": result.is_critical,
		"was_breached": result.was_breached,
		"source_effect": result.source_effect,
		"source_action": result.source_action,
	}, true)
	await _process_on_hit_triggers(attacker, target, battle_manager, hit_event_context)
	await attacker._fire_condition_event(Trigger.TriggerType.ON_HIT, hit_event_context)
	if lifedrain_scalar > 0.0:
		attacker.take_healing(lifedrain_amount(actual_damage, lifedrain_scalar))


static func lifedrain_amount(actual_damage: int, scalar: float) -> int:
	return maxi(0, floori(float(actual_damage) * maxf(0.0, scalar)))


func _apply_guard_behavior(
	target: BattleCombatant,
	resolved_damage_type: Action.DamageType,
) -> void:
	if not _resolved_type_shreds_guard(resolved_damage_type):
		target.presentation_event.emit(target, &"impact", {"intensity": 0.5})
		return
	if not target.is_breached and target.current_guard == 0:
		await target.breach()
		return
	await target.modify_guard(-1)
	target.presentation_event.emit(target, &"impact", {"intensity": 0.5})


func _resolved_type_shreds_guard(resolved_damage_type: Action.DamageType) -> bool:
	return resolved_damage_type in [
		Action.DamageType.KINETIC,
		Action.DamageType.ENERGY,
	]


func _is_target_sequence_complete(
	plan: DamageHitPlan,
	hit_index: int,
	target: BattleCombatant,
) -> bool:
	if target.is_defeated or hit_index >= plan.planned_hit_count - 1:
		return true
	var plan_candidates := plan.candidates
	if plan.target_mode == DamageHitPlan.TargetMode.SINGLE:
		return false
	return hit_index + 1 >= plan_candidates.size() \
		or plan_candidates[hit_index + 1] != target


func _should_wait_between_hits(
	plan: DamageHitPlan,
	hit_index: int,
	target: BattleCombatant,
) -> bool:
	if hit_index >= plan.planned_hit_count - 1:
		return false
	if plan.target_mode == DamageHitPlan.TargetMode.RANDOM:
		return true
	if plan.target_mode == DamageHitPlan.TargetMode.SINGLE:
		return true
	var plan_candidates := plan.candidates
	return hit_index + 1 < plan_candidates.size() \
		and plan_candidates[hit_index + 1] == target


func _filter_valid_targets(list: Array) -> Array:
	var valid := []
	for target in list:
		if target and is_instance_valid(target) and not target.is_defeated:
			valid.append(target)
	return valid


func _resolve_potency(context: DamageContext) -> DamageResolver.ResolvedPotency:
	return DamageResolver.resolve_potency(potency, scaling_rules, context)


func _requires_battlefield_context() -> bool:
	for rule: DamageScalingRule in scaling_rules:
		if rule != null and rule.requires_battlefield_context():
			return true
	return false


func _has_current_hit_battlefield_scaling() -> bool:
	for rule: DamageScalingRule in scaling_rules:
		if rule != null \
			and rule.phase == DamageScalingRule.Phase.CURRENT_HIT \
			and rule.requires_battlefield_context():
			return true
	return false


func _resolve_current_hit_potency(
	effect_start_potency: DamageResolver.ResolvedPotency,
	context: DamageContext,
) -> DamageResolver.ResolvedPotency:
	var current_hit_potency := DamageResolver.resolve_potency(
		potency,
		scaling_rules,
		context,
		DamageScalingRule.Phase.CURRENT_HIT,
	)
	return DamageResolver.combine_potency(
		potency,
		effect_start_potency,
		current_hit_potency,
	)


func _get_dynamic_potency(
	attacker: BattleCombatant,
	target: BattleCombatant,
	context: Dictionary = {},
	battle_manager: BattleManager = null,
	action: Action = null,
) -> float:
	var source_action := _resolve_source_action(action, context)
	var effect_context := DamageContext.capture(
		attacker, null, battle_manager, source_action, self, context,
	)
	var effect_start_potency := _resolve_potency(effect_context)
	if target == null:
		return effect_start_potency.potency
	var hit_context := DamageContext.capture(
		attacker, target, battle_manager, source_action, self, context,
	)
	return _resolve_current_hit_potency(effect_start_potency, hit_context).potency


func _resolve_source_action(action: Action, context: Dictionary) -> Action:
	if action != null:
		return action
	var inherited_source: Variant = context.get("source_action")
	if inherited_source is Action:
		return inherited_source as Action
	var inherited_action: Variant = context.get("action")
	return inherited_action as Action if inherited_action is Action else null


func _roll_percent(chance: int, battle_manager: BattleManager) -> bool:
	return battle_manager.combat_roll_percent(chance)


func _pick_random_target(
	candidates: Array,
	battle_manager: BattleManager,
) -> BattleCombatant:
	var selected := battle_manager.combat_random_actor(candidates)
	return BattleCombatant.resolve_model(selected) \
		if is_instance_valid(selected) else null


func _modify_damage_request(
	request: DamageRequest,
	_hit_context: DamageContext,
) -> DamageRequest:
	return request


func _play_hit_audio() -> void:
	AudioManager.play_sfx("pistol", 0.5)


func _apply_calculated_hit(
	target: BattleCombatant,
	result: DamageResult,
	attacker: BattleCombatant,
	resolved_damage_type: Action.DamageType,
	is_critical: bool,
) -> int:
	return await target.take_one_hit(result, self, attacker, resolved_damage_type)


func _get_pre_hit_triggers(
	attacker: BattleCombatant,
	target: BattleCombatant,
) -> Dictionary:
	var context := {}
	for trigger in pre_hit_triggers:
		var condition_met := false

		match trigger.condition:
			PreHitTrigger.PreHitCondition.IF_TARGET_IS_BREACHED:
				condition_met = target.is_breached
			PreHitTrigger.PreHitCondition.ALWAYS:
				condition_met = true
			PreHitTrigger.PreHitCondition.IF_TARGET_HAS_CONDITION:
				condition_met = target.has_condition(trigger.string_context)
			PreHitTrigger.PreHitCondition.IF_TARGET_HAS_ANY_DEBUFF:
				condition_met = target.count_debuffs() > 0
		if condition_met:
			for effect in trigger.effects_to_run:
				effect.execute(context, attacker, target)
	return context


func _resolve_forced_damage_type(
	attacker: BattleCombatant,
	target: BattleCombatant,
	pre_hit_context: Dictionary,
) -> Action.DamageType:
	var decision := _resolve_damage_type_decision(attacker, target, pre_hit_context)
	if decision.condition_to_consume != null:
		await target.remove_condition(decision.condition_to_consume.condition_name)
	return decision.forced_damage_type


func _resolve_damage_type_decision(
	attacker: BattleCombatant,
	target: BattleCombatant,
	pre_hit_context: Dictionary,
) -> DamageTypeDecision:
	if pre_hit_context.has("final_damage_type"):
		var context_type := pre_hit_context.final_damage_type as Action.DamageType
		var resolved_type := damage_type \
			if context_type == Action.DamageType.NONE else context_type
		return DamageTypeDecision.new(resolved_type, context_type, null)
	var condition := _find_forced_damage_condition(attacker, target)
	if condition == null:
		return DamageTypeDecision.new(
			damage_type, Action.DamageType.NONE, null,
		)
	var condition_to_consume: Condition = null
	if Trigger.TriggerType.ON_TRIGGERED in condition.remove_on_triggers:
		condition_to_consume = condition
	return DamageTypeDecision.new(
		condition.force_damage_type,
		condition.force_damage_type,
		condition_to_consume,
	)


func _find_forced_damage_condition(
	attacker: BattleCombatant,
	target: BattleCombatant,
) -> Condition:
	if target == null:
		return null
	var attacker_hero_type := Action.HeroType.ALL
	if attacker.is_hero():
		var hero_name_key := attacker.actor_name.to_upper()
		if Action.HeroType.has(hero_name_key):
			attacker_hero_type = Action.HeroType[hero_name_key]

	for index in range(target.active_conditions.size() - 1, -1, -1):
		var condition := target.active_conditions[index]
		if condition.force_damage_type == Action.DamageType.NONE:
			continue
		if condition.triggered_by not in [Action.HeroType.ALL, attacker_hero_type]:
			continue
		return condition
	return null


func _process_on_hit_triggers(
	attacker: BattleCombatant,
	target: BattleCombatant,
	battle_manager: BattleManager,
	context: Dictionary,
) -> void:
	for hit_trigger in on_hit_triggers:
		var condition_met := false

		match hit_trigger.condition:
			HitTrigger.HitCondition.ALWAYS:
				condition_met = true
			HitTrigger.HitCondition.IF_TARGET_IS_BREACHED:
				condition_met = target.is_breached
			HitTrigger.HitCondition.IF_TARGET_HAS_DEBUFF:
				if hit_trigger.context.is_empty():
					condition_met = target.count_debuffs() > 0
				else:
					condition_met = target.has_condition(hit_trigger.context)
			HitTrigger.HitCondition.IF_ATTACKER_HAS_BUFF:
				if hit_trigger.context.is_empty():
					condition_met = attacker.active_conditions.any(func(condition):
						return condition.condition_type == Condition.ConditionType.BUFF \
							and not condition.is_passive
					)
				else:
					condition_met = attacker.has_condition(hit_trigger.context)
			HitTrigger.HitCondition.IF_TARGET_IS_VULNERABLE_OR_BREACHED:
				condition_met = target.is_in_danger or target.is_breached

		if condition_met:
			print("On-hit trigger fired!")
			for effect in hit_trigger.effects_to_run:
				var targets := BattleCombatant.resolve_models(battle_manager.get_targets(
					effect.target_type, attacker.is_hero(), [target], target,
				))
				if effect is Effect_Damage:
					await battle_manager.wait(0.25)
				await battle_manager.execute_triggered_effect(
					attacker, effect, targets, null, context,
				)
