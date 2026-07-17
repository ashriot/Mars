class_name DamagePreview
extends RefCounted


static func for_effect(
	effect: Effect_Damage,
	attacker: ActorCard,
	target: ActorCard,
	action: Action,
	distribution_count: int,
	critical: bool,
	pre_hit_context: Dictionary = {},
) -> DamageResult:
	var resolver_target := target
	var neutral_target := resolver_target == null
	var owns_resolver_target := neutral_target
	if neutral_target:
		resolver_target = _neutral_target()
	var decision := effect._resolve_damage_type_decision(
		attacker, null if neutral_target else target, pre_hit_context,
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
		neutral_target,
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


static func _capture_preview_context(
	effect: Effect_Damage,
	attacker: ActorCard,
	target: ActorCard,
	action: Action,
	resolved_damage_type: Action.DamageType,
	neutral_target: bool,
) -> DamageContext:
	var attacker_state := CombatantSnapshot.capture(attacker)
	var paid_focus_cost := 0
	var remaining_focus := attacker_state.current_focus
	if attacker is HeroCard and action != null:
		paid_focus_cost = (attacker as HeroCard).get_scaled_focus_cost(action.focus_cost)
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
	target: ActorCard,
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


static func _neutral_target() -> ActorCard:
	var target := ActorCard.new()
	target.current_stats = ActorStats.new()
	target.current_hp = 0
	target.current_guard = 0
	target.is_breached = false
	target.is_defeated = false
	return target


static func _target_without_condition(
	target: ActorCard,
	excluded_condition: Condition,
) -> ActorCard:
	var preview_target := ActorCard.new()
	preview_target.actor_name = target.actor_name
	preview_target.current_stats = target.current_stats
	preview_target.current_hp = target.current_hp
	preview_target.current_guard = target.current_guard
	preview_target.current_ct = target.current_ct
	preview_target.ct_speed_scale = target.ct_speed_scale
	preview_target.battle_priority = target.battle_priority
	preview_target.is_breached = target.is_breached
	preview_target.is_in_danger = target.is_in_danger
	preview_target.is_defeated = target.is_defeated
	var retained_conditions: Array[Condition] = []
	for condition: Condition in target.active_conditions:
		if condition != excluded_condition:
			retained_conditions.append(condition)
	preview_target.active_conditions = retained_conditions
	preview_target.active_traits = target.active_traits.duplicate()
	return preview_target
