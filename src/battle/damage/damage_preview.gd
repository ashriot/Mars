class_name DamagePreview
extends RefCounted


static func for_effect(
	effect: Effect_Damage,
	attacker: ActorCard,
	target: ActorCard,
	action: Action,
	distribution_count: int,
	critical: bool,
) -> DamageResult:
	var resolver_target := target
	var owns_neutral_target := resolver_target == null
	if owns_neutral_target:
		resolver_target = _neutral_target()
	var resolved_damage_type := effect._resolve_preview_damage_type(
		attacker, null if owns_neutral_target else resolver_target,
	)
	var damage_context := _capture_preview_context(
		effect,
		attacker,
		resolver_target,
		action,
		resolved_damage_type,
		owns_neutral_target,
	)
	var resolved_potency := effect._resolve_potency(damage_context)
	var result := DamageResolver.resolve_hit(
		attacker,
		resolver_target,
		effect.power_type,
		resolved_potency,
		distribution_count,
		resolved_damage_type,
		critical,
		damage_context,
		Callable(effect, "_modify_damage_request"),
	)
	if owns_neutral_target:
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
