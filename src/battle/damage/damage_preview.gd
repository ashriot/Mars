class_name DamagePreview
extends RefCounted


class Sequence extends RefCounted:
	var _results: Array[DamageResult]
	var _is_complete: bool
	var _is_ordered: bool
	var _planned_hit_count: int
	var _distribution_count: int
	var _target_count: int

	var results: Array[DamageResult]:
		get:
			var copy: Array[DamageResult] = []
			copy.assign(_results)
			return copy
	var is_complete: bool:
		get: return _is_complete
	var is_ordered: bool:
		get: return _is_ordered
	var planned_hit_count: int:
		get: return _planned_hit_count
	var distribution_count: int:
		get: return _distribution_count
	var target_count: int:
		get: return _target_count


	func _init(
		sequence_results: Array[DamageResult],
		sequence_is_complete: bool,
		sequence_is_ordered: bool,
		sequence_planned_hit_count: int,
		sequence_distribution_count: int,
		sequence_target_count: int,
	) -> void:
		_results = sequence_results.duplicate()
		_is_complete = sequence_is_complete
		_is_ordered = sequence_is_ordered
		_planned_hit_count = sequence_planned_hit_count
		_distribution_count = sequence_distribution_count
		_target_count = sequence_target_count


static func for_plan(
	effect: Effect_Damage,
	attacker: BattleCombatant,
	target_nodes: Array[BattleCombatant],
	action: Action,
	critical: bool,
	battle_manager: BattleManager = null,
	pre_hit_context: Dictionary = {},
) -> Sequence:
	if not is_instance_valid(attacker):
		return Sequence.new([], false, false, effect.hit_count, 1, target_nodes.size())
	var resolved_hit_count := effect._resolve_hit_count(attacker)
	if attacker.current_stats == null or target_nodes.is_empty():
		return Sequence.new([], false, false, resolved_hit_count, 1, target_nodes.size())
	if effect._requires_battlefield_context() and battle_manager == null:
		return Sequence.new([], false, false, resolved_hit_count, 1, target_nodes.size())
	var valid_targets: Array[BattleCombatant] = []
	for target: BattleCombatant in target_nodes:
		if not is_instance_valid(target):
			return Sequence.new(
				[], false, false, resolved_hit_count, 1, target_nodes.size(),
			)
		if target.current_stats == null or target.is_defeated:
			return Sequence.new(
				[], false, false, resolved_hit_count, 1, target_nodes.size(),
			)
		valid_targets.append(target)
	var plan := effect._build_hit_plan(valid_targets, action, resolved_hit_count)
	var preview_attacker := _preview_attacker_snapshot(attacker, action)
	var effect_counts := _living_counts(attacker, null, battle_manager)
	var trigger_context := {
		"paid_focus_cost": _paid_focus_cost(attacker, action),
	}
	var effect_context := DamageContext.new(
		preview_attacker,
		null,
		effect_counts.allies,
		effect_counts.enemies,
		action,
		effect,
		trigger_context,
	)
	var effect_start_potency := effect._resolve_potency(effect_context)
	var results: Array[DamageResult] = []
	if plan.target_mode == DamageHitPlan.TargetMode.RANDOM:
		for live_target: BattleCombatant in valid_targets:
			var preview_target := _copy_target(live_target)
			var preview_targets := {live_target: preview_target}
			for hit_index in plan.planned_hit_count:
				if preview_target.is_defeated:
					break
				results.append(_resolve_preview_hit(
					effect,
					attacker,
					preview_attacker,
					live_target,
					preview_target,
					action,
					battle_manager,
					preview_targets,
					critical,
					pre_hit_context,
					trigger_context,
					effect_start_potency,
					plan.distribution_count,
				))
				if preview_target.is_defeated \
					and hit_index < plan.planned_hit_count - 1 \
					and valid_targets.size() > 1 \
					and effect._has_current_hit_battlefield_scaling():
					preview_target.free()
					return Sequence.new(
						[],
						false,
						false,
						plan.planned_hit_count,
						plan.distribution_count,
						valid_targets.size(),
					)
			preview_target.free()
		return Sequence.new(
			results,
			true,
			false,
			plan.planned_hit_count,
			plan.distribution_count,
			valid_targets.size(),
		)

	var preview_targets: Dictionary = {}
	var plan_candidates := plan.candidates
	for hit_index in plan.planned_hit_count:
		var live_target: BattleCombatant = null
		if plan.target_mode == DamageHitPlan.TargetMode.SINGLE:
			live_target = plan_candidates[0] as BattleCombatant \
				if not plan_candidates.is_empty() else null
		elif hit_index < plan_candidates.size():
			live_target = plan_candidates[hit_index] as BattleCombatant
		if live_target == null:
			continue
		if not preview_targets.has(live_target):
			preview_targets[live_target] = _copy_target(live_target)
		var preview_target := preview_targets[live_target] as BattleCombatant
		if preview_target.is_defeated:
			continue
		results.append(_resolve_preview_hit(
			effect,
			attacker,
			preview_attacker,
			live_target,
			preview_target,
			action,
			battle_manager,
			preview_targets,
			critical,
			pre_hit_context,
			trigger_context,
			effect_start_potency,
			plan.distribution_count,
		))
	for preview_target: BattleCombatant in preview_targets.values():
		preview_target.free()
	return Sequence.new(
		results,
		true,
		plan.target_mode == DamageHitPlan.TargetMode.SINGLE,
		plan.planned_hit_count,
		plan.distribution_count,
		valid_targets.size(),
	)


static func for_effect(
	effect: Effect_Damage,
	attacker: BattleCombatant,
	target: BattleCombatant,
	action: Action,
	distribution_count: int,
	critical: bool,
	pre_hit_context: Dictionary = {},
) -> DamageResult:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return null
	var resolver_target := target
	var owns_resolver_target := false
	var decision := effect._resolve_damage_type_decision(
		attacker, target, pre_hit_context,
	)
	if decision.condition_to_consume != null:
		resolver_target = _target_without_condition(
			target, decision.condition_to_consume,
		)
		owns_resolver_target = true
	var resolved_damage_type := decision.resolved_damage_type
	var hit_context := _capture_preview_context(
		effect,
		attacker,
		resolver_target,
		action,
		resolved_damage_type,
		false,
	)
	var effect_context := DamageContext.new(
		hit_context.attacker,
		null,
		hit_context.other_living_allies,
		hit_context.other_living_enemies,
		hit_context.source_action,
		hit_context.source_effect,
		hit_context.trigger_context,
	)
	var effect_start_potency := effect._resolve_potency(effect_context)
	var resolved_potency := effect._resolve_current_hit_potency(
		effect_start_potency,
		hit_context,
	)
	var result := DamageResolver.resolve_hit(
		attacker,
		resolver_target,
		effect.power_type,
		resolved_potency,
		distribution_count,
		resolved_damage_type,
		critical,
		hit_context,
		Callable(effect, "_modify_damage_request"),
	)
	if owns_resolver_target:
		resolver_target.free()
	return result


static func _resolve_preview_hit(
	effect: Effect_Damage,
	attacker: BattleCombatant,
	preview_attacker: CombatantSnapshot,
	live_target: BattleCombatant,
	preview_target: BattleCombatant,
	action: Action,
	battle_manager: BattleManager,
	preview_targets: Dictionary,
	critical: bool,
	pre_hit_context: Dictionary,
	trigger_context: Dictionary,
	effect_start_potency: DamageResolver.ResolvedPotency,
	distribution_count: int,
) -> DamageResult:
	var decision := effect._resolve_damage_type_decision(
		attacker, preview_target, pre_hit_context,
	)
	if decision.condition_to_consume != null:
		preview_target.active_conditions.erase(decision.condition_to_consume)
	var resolved_damage_type := decision.resolved_damage_type
	_apply_preview_guard(effect, preview_target, resolved_damage_type)
	var hit_counts := _living_counts(
		attacker, live_target, battle_manager, preview_targets,
	)
	var hit_context := DamageContext.new(
		preview_attacker,
		CombatantSnapshot.capture(preview_target),
		hit_counts.allies,
		hit_counts.enemies,
		action,
		effect,
		trigger_context,
	)
	var resolved_potency := effect._resolve_current_hit_potency(
		effect_start_potency, hit_context,
	)
	var result := DamageResolver.resolve_hit(
		attacker,
		preview_target,
		effect.power_type,
		resolved_potency,
		distribution_count,
		resolved_damage_type,
		critical,
		hit_context,
		Callable(effect, "_modify_damage_request"),
	)
	preview_target.current_hp = maxi(
		0, preview_target.current_hp - result.final_damage,
	)
	preview_target.is_defeated = preview_target.current_hp == 0
	return result


static func _apply_preview_guard(
	effect: Effect_Damage,
	target: BattleCombatant,
	resolved_damage_type: Action.DamageType,
) -> void:
	if not effect._resolved_type_shreds_guard(resolved_damage_type):
		return
	if not target.is_breached and target.current_guard == 0:
		target.is_breached = true
		return
	target.current_guard = maxi(0, target.current_guard - 1)


static func _preview_attacker_snapshot(
	attacker: BattleCombatant,
	action: Action,
) -> CombatantSnapshot:
	var attacker_state := CombatantSnapshot.capture(attacker)
	return CombatantSnapshot.new(
		attacker_state.current_hp,
		maxi(0, attacker_state.current_focus - _paid_focus_cost(attacker, action)),
		attacker_state.current_guard,
		attacker_state.is_breached,
		attacker_state.is_defeated,
		attacker_state.condition_names,
	)


static func _paid_focus_cost(attacker: BattleCombatant, action: Action) -> int:
	if attacker is HeroCombatant and action != null:
		return (attacker as HeroCombatant).get_scaled_focus_cost(action.focus_cost)
	return 0


static func _living_counts(
	attacker: BattleCombatant,
	target: BattleCombatant,
	battle_manager: BattleManager,
	preview_targets: Dictionary = {},
) -> Dictionary:
	if battle_manager == null:
		return {"allies": 0, "enemies": 0}
	var other_living_allies := 0
	var other_living_enemies := 0
	for combatant: BattleCombatant in battle_manager.actor_list:
		if not is_instance_valid(combatant):
			continue
		var defeated := combatant.is_defeated
		if preview_targets.has(combatant):
			defeated = (preview_targets[combatant] as BattleCombatant).is_defeated
		if defeated:
			continue
		var is_attacker_ally := combatant.faction == attacker.faction
		if is_attacker_ally:
			if combatant != attacker:
				other_living_allies += 1
		elif combatant != target:
			other_living_enemies += 1
	return {
		"allies": other_living_allies,
		"enemies": other_living_enemies,
	}


static func _copy_target(target: BattleCombatant) -> BattleCombatant:
	var preview_target: BattleCombatant = HeroCombatant.new() \
		if target.is_hero() else EnemyCombatant.new()
	preview_target.setup_base(
		_copy_stats(target.current_stats), target.faction,
	)
	preview_target.current_hp = target.current_hp
	preview_target.current_guard = target.current_guard
	preview_target.current_ct = target.current_ct
	preview_target.ct_speed_scale = target.ct_speed_scale
	preview_target.battle_priority = target.battle_priority
	preview_target.is_breached = target.is_breached
	preview_target.is_in_danger = target.is_in_danger
	preview_target.is_defeated = target.is_defeated
	preview_target.active_conditions.assign(target.active_conditions.map(
		func(condition: Condition): return condition.duplicate(true)
	))
	preview_target.active_traits.assign(target.active_traits.map(
		func(trait_item: Trait): return trait_item.duplicate(true)
	))
	if preview_target is HeroCombatant and target is HeroCombatant:
		(preview_target as HeroCombatant).current_focus = (
			target as HeroCombatant
		).current_focus
	return preview_target


static func _capture_preview_context(
	effect: Effect_Damage,
	attacker: BattleCombatant,
	target: BattleCombatant,
	action: Action,
	resolved_damage_type: Action.DamageType,
	neutral_target: bool,
) -> DamageContext:
	var attacker_state := CombatantSnapshot.capture(attacker)
	var paid_focus_cost := 0
	var remaining_focus := attacker_state.current_focus
	if attacker is HeroCombatant and action != null:
		paid_focus_cost = (attacker as HeroCombatant).get_scaled_focus_cost(action.focus_cost)
		remaining_focus = maxi(0, remaining_focus - paid_focus_cost)
	var preview_attacker := CombatantSnapshot.new(
		attacker_state.current_hp,
		remaining_focus,
		attacker_state.current_guard,
		attacker_state.is_breached,
		attacker_state.is_defeated,
		attacker_state.condition_names,
	)
	var preview_target := _capture_preview_target(
		effect, target, resolved_damage_type, neutral_target,
	)
	return DamageContext.new(
		preview_attacker,
		preview_target,
		0,
		0,
		action,
		effect,
		{"paid_focus_cost": paid_focus_cost},
	)


static func _capture_preview_target(
	effect: Effect_Damage,
	target: BattleCombatant,
	resolved_damage_type: Action.DamageType,
	neutral_target: bool,
) -> CombatantSnapshot:
	if neutral_target:
		return CombatantSnapshot.new(0, 0, 0, false, false, [])
	var target_state := CombatantSnapshot.capture(target)
	var breached_for_hit := target_state.is_breached
	if target.current_guard == 0 \
		and effect._resolved_type_shreds_guard(resolved_damage_type):
		breached_for_hit = true
	return CombatantSnapshot.new(
		target_state.current_hp,
		target_state.current_focus,
		target_state.current_guard,
		breached_for_hit,
		target_state.is_defeated,
		target_state.condition_names,
	)


static func _neutral_target() -> BattleCombatant:
	var target := BattleCombatant.new()
	target.setup_base(ActorStats.new(), BattleCombatant.Faction.ENEMY)
	target.current_hp = 0
	target.current_guard = 0
	target.is_breached = false
	target.is_defeated = false
	return target


static func _target_without_condition(
	target: BattleCombatant,
	excluded_condition: Condition,
) -> BattleCombatant:
	var preview_target := _copy_target(target)
	var retained_conditions: Array[Condition] = []
	for condition: Condition in target.active_conditions:
		if condition != excluded_condition:
			retained_conditions.append(condition.duplicate(true))
	preview_target.active_conditions = retained_conditions
	return preview_target


static func _copy_stats(source: ActorStats) -> ActorStats:
	var stats := ActorStats.new()
	stats.actor_name = source.actor_name
	stats.max_hp = source.max_hp
	stats.starting_guard = source.starting_guard
	stats.starting_focus = source.starting_focus
	stats.attack = source.attack
	stats.psyche = source.psyche
	stats.overload = source.overload
	stats.speed = source.speed
	stats.aim = source.aim
	stats.precision = source.precision
	stats.kinetic_defense = source.kinetic_defense
	stats.energy_defense = source.energy_defense
	return stats
