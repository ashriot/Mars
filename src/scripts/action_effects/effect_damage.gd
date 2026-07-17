# Effect_Damage.gd
extends ActionEffect
class_name Effect_Damage

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


func execute(
	attacker: ActorCard,
	parent_targets: Array,
	battle_manager: BattleManager,
	action: Action = null,
	context: Dictionary = {},
) -> void:
	var resolved_hit_count := _resolve_hit_count(attacker, context)
	var plan := _build_hit_plan(parent_targets, action, resolved_hit_count)
	var effect_context := DamageContext.capture(
		attacker, null, battle_manager, action, self, context,
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
		var target := _resolve_planned_target(plan, hit_index)
		if target == null:
			if plan.target_mode == DamageHitPlan.TargetMode.RANDOM:
				break
			continue
		if not _can_continue_hit(attacker, target, battle_manager):
			continue

		await _execute_one_hit(
			attacker, target, battle_manager, action, context, plan, resolved_potency,
		)

		if plan.target_mode != DamageHitPlan.TargetMode.RANDOM \
			and not after_attack_fired.has(target) \
			and _is_target_sequence_complete(plan, hit_index, target):
			after_attack_fired[target] = true
			await target._fire_condition_event(
				Trigger.TriggerType.AFTER_BEING_ATTACKED, context,
			)

		if _should_wait_between_hits(plan, hit_index, target):
			await battle_manager.wait(0.15)


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


func _resolve_hit_count(_attacker: ActorCard, _context: Dictionary = {}) -> int:
	return hit_count


func _resolve_planned_target(plan: DamageHitPlan, hit_index: int) -> ActorCard:
	var plan_candidates := plan.candidates
	if plan.target_mode == DamageHitPlan.TargetMode.RANDOM:
		return _pick_random_target(_filter_valid_targets(plan_candidates))
	if plan_candidates.is_empty():
		return null
	if plan.target_mode == DamageHitPlan.TargetMode.SINGLE:
		return plan_candidates[0] as ActorCard
	if hit_index >= plan_candidates.size():
		return null
	return plan_candidates[hit_index] as ActorCard


func _can_continue_hit(
	attacker: ActorCard,
	target: ActorCard,
	battle_manager: BattleManager,
) -> bool:
	return battle_manager.current_state != BattleManager.State.BATTLE_OVER \
		and not attacker.is_defeated \
		and is_instance_valid(target) \
		and not target.is_defeated


func _execute_one_hit(
	attacker: ActorCard,
	target: ActorCard,
	battle_manager: BattleManager,
	action: Action,
	context: Dictionary,
	plan: DamageHitPlan,
	resolved_potency: DamageResolver.ResolvedPotency,
) -> void:
	var pre_hit_context := _get_pre_hit_triggers(attacker, target)
	var forced_damage_type := _resolve_forced_damage_type(
		attacker, target, pre_hit_context,
	)
	var resolved_damage_type := damage_type \
		if forced_damage_type == Action.DamageType.NONE \
		else forced_damage_type
	await _apply_guard_behavior(target, resolved_damage_type)

	var hit_context := DamageContext.capture(
		attacker, target, battle_manager, action, self, context,
	)
	var crit_chance := attacker.get_aim() + target.get_incoming_aim_mods()
	crit_chance += int(pre_hit_context.get("aim_bonus", 0))
	var is_critical := _roll_percent(clampi(crit_chance, 0, 100))
	var result := DamageResolver.resolve_hit(
		attacker,
		target,
		power_type,
		resolved_potency,
		plan.distribution_count,
		resolved_damage_type,
		is_critical,
		hit_context,
		Callable(self, "_modify_damage_request"),
	)

	_play_hit_audio()
	await _apply_calculated_hit(
		target, result, attacker, resolved_damage_type, is_critical,
	)
	await _process_on_hit_triggers(attacker, target, battle_manager)
	await attacker._fire_condition_event(Trigger.TriggerType.ON_HIT, context)
	if lifedrain_scalar > 0.0:
		attacker.take_healing(int(result.raw_damage * lifedrain_scalar))


func _apply_guard_behavior(
	target: ActorCard,
	resolved_damage_type: Action.DamageType,
) -> void:
	if not _resolved_type_shreds_guard(resolved_damage_type):
		target.shake_panel()
		return
	if not target.is_breached and target.current_guard == 0:
		await target.breach()
		return
	await target.modify_guard(-1)
	target.shake_panel()


func _resolved_type_shreds_guard(resolved_damage_type: Action.DamageType) -> bool:
	return resolved_damage_type in [
		Action.DamageType.KINETIC,
		Action.DamageType.ENERGY,
	]


func _is_target_sequence_complete(
	plan: DamageHitPlan,
	hit_index: int,
	target: ActorCard,
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
	target: ActorCard,
) -> bool:
	if hit_index >= plan.planned_hit_count - 1:
		return false
	if plan.target_mode == DamageHitPlan.TargetMode.RANDOM:
		return true
	if target.is_defeated:
		return false
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


func _get_dynamic_potency(
	attacker: ActorCard,
	target: ActorCard,
	context: Dictionary = {},
	battle_manager: BattleManager = null,
	action: Action = null,
) -> float:
	var damage_context := DamageContext.capture(
		attacker, target, battle_manager, action, self, context,
	)
	return _resolve_potency(damage_context).potency


func _roll_percent(chance: int) -> bool:
	return randi_range(1, 100) <= chance


func _pick_random_target(candidates: Array) -> ActorCard:
	return candidates.pick_random() as ActorCard if not candidates.is_empty() else null


func _modify_damage_request(
	request: DamageRequest,
	_hit_context: DamageContext,
) -> DamageRequest:
	return request


func _play_hit_audio() -> void:
	AudioManager.play_sfx("pistol", 0.5)


func _apply_calculated_hit(
	target: ActorCard,
	result: DamageResult,
	attacker: ActorCard,
	resolved_damage_type: Action.DamageType,
	is_critical: bool,
) -> void:
	await target.take_one_hit(
		result.final_damage, self, attacker, resolved_damage_type, is_critical,
	)


func _get_pre_hit_triggers(attacker: ActorCard, target: ActorCard) -> Dictionary:
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
	attacker: ActorCard,
	target: ActorCard,
	pre_hit_context: Dictionary,
) -> Action.DamageType:
	if pre_hit_context.has("final_damage_type"):
		return pre_hit_context.final_damage_type as Action.DamageType
	var attacker_hero_type := Action.HeroType.ALL
	if attacker is HeroCard:
		var hero_name_key := attacker.actor_name.to_upper()
		if Action.HeroType.has(hero_name_key):
			attacker_hero_type = Action.HeroType[hero_name_key]

	for index in range(target.active_conditions.size() - 1, -1, -1):
		var condition := target.active_conditions[index]
		if condition.force_damage_type == Action.DamageType.NONE:
			continue
		if condition.triggered_by not in [Action.HeroType.ALL, attacker_hero_type]:
			continue
		var forced_damage_type := condition.force_damage_type
		for remove_trigger in condition.remove_on_triggers:
			if remove_trigger == Trigger.TriggerType.ON_TRIGGERED:
				target.remove_condition(condition.condition_name)
				break
		return forced_damage_type
	return Action.DamageType.NONE


func _process_on_hit_triggers(
	attacker: ActorCard,
	target: ActorCard,
	battle_manager: BattleManager,
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
					condition_met = attacker.count_debuffs() > 0
				else:
					condition_met = attacker.has_condition(hit_trigger.context)

		if condition_met:
			print("On-hit trigger fired!")
			for effect in hit_trigger.effects_to_run:
				var targets := battle_manager.get_targets(
					effect.target_type, attacker is HeroCard, [target], target,
				)
				if effect is Effect_Damage:
					await battle_manager.wait(0.25)
				await battle_manager.execute_triggered_effect(
					attacker, effect, targets, null,
				)
