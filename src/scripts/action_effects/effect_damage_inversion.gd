extends Effect_Damage
class_name Effect_Damage_Inversion

@export_range(0, 99, 1) var max_guard_points: int = 0


func resolve_guard_points(current_guard: int) -> int:
	var available_guard := maxi(0, current_guard)
	return mini(available_guard, max_guard_points) \
		if max_guard_points > 0 else available_guard


func _resolve_current_hit_potency(
	effect_start_potency: DamageResolver.ResolvedPotency,
	context: DamageContext,
) -> DamageResolver.ResolvedPotency:
	var resolved := super._resolve_current_hit_potency(
		effect_start_potency,
		context,
	)
	var trigger_context := context.trigger_context
	var guard_destroyed := 1
	if trigger_context.has("guard_destroyed"):
		guard_destroyed = int(trigger_context["guard_destroyed"])
	elif context.target != null:
		guard_destroyed = resolve_guard_points(context.target.current_guard)
	guard_destroyed = maxi(0, guard_destroyed)
	if guard_destroyed == 1:
		return resolved
	var scaled_unclamped := resolved.unclamped_potency * float(guard_destroyed)
	var guard_bonus := scaled_unclamped - resolved.unclamped_potency
	var contributions := resolved.contributions
	contributions.append(DamageContribution.new(
		&"guard_destroyed",
		DamageContribution.Stage.POTENCY,
		guard_bonus,
	))
	return DamageResolver.ResolvedPotency.new(
		resolved.base_potency,
		maxf(0.0, scaled_unclamped),
		contributions,
		scaled_unclamped,
	)


func execute(
	attacker_node: Node,
	parent_targets: Array,
	battle_manager: BattleManager,
	action: Action = null,
	context: Dictionary = {},
) -> void:
	var attacker := BattleCombatant.resolve_model(attacker_node)
	var targets := BattleCombatant.resolve_models(parent_targets)
	for target: BattleCombatant in targets:
		if not is_instance_valid(target) or target.is_defeated:
			continue
		var guard_destroyed := resolve_guard_points(target.current_guard)
		if guard_destroyed <= 0:
			continue
		await target.modify_guard(-guard_destroyed)
		var damage_context := context.duplicate()
		damage_context["guard_destroyed"] = guard_destroyed
		await super.execute(
			attacker,
			[target],
			battle_manager,
			action,
			damage_context,
		)
