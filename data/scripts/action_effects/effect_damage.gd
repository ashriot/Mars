# Effect_Damage.gd
extends ActionEffect
class_name Effect_Damage

# --- Base Damage Properties ---
@export var potency: float = 1.0
@export var split_damage: bool = false
@export var hit_count: int = 1
@export var shreds_guard: bool = true
@export var power_type: Action.PowerType = Action.PowerType.ATTACK
@export var damage_type: Action.DamageType = Action.DamageType.KINETIC

@export var potency_per_focus: float = 0.0
@export var potency_scalar_per_focus: float = 0.0
@export var on_hit_triggers: Array[HitTrigger]
@export var pre_hit_triggers: Array[PreHitTrigger]

func execute(attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, action: Action = null, _context: Dictionary = {}) -> void:
	var final_targets: Array = parent_targets

	print("\n--- Damage Effect for ", hit_count, " hit(s) ---")
	var random = false
	var focus_cost = 0

	if action:
		focus_cost = action.focus_cost
		if action.target_type == Action.TargetType.RANDOM_ENEMY:
			random = true
			if final_targets.is_empty():
				print("RANDOM_ENEMY: No living enemies to target!")
				return

	var target: ActorCard = null
	for t in final_targets.size():
		for i in hit_count:
			if random:
				target = final_targets.pick_random() as ActorCard
			else:
				target = final_targets[t]
			var pre_hit_context = _get_pre_hit_triggers(attacker, target)
			var dynamic_potency = get_dynamic_potency(attacker, target, focus_cost)
			print("Final Potency: ", dynamic_potency)
			if not target or not is_instance_valid(target):
				continue

			if target.is_defeated and not random:
				break

			if damage_type == Action.DamageType.PIERCING:
				target.shake_panel()
			else:
				if not target.is_breached and target.current_guard == 0:
					target.breach()
				else:
					target.modify_guard(-1)
					target.shake_panel()

			if split_damage: dynamic_potency /= final_targets.size()
			var is_crit: bool = false
			var crit_chance: int = attacker.get_precision() + target.get_incoming_precision_mods()
			if pre_hit_context.has("precision_bonus"):
				crit_chance += pre_hit_context.precision_bonus
			if randi_range(1, 100) <= crit_chance:
				is_crit = true

			var power_for_hit = attacker.get_power(power_type)
			if target.is_breached:
				power_for_hit += attacker.current_stats.overload

			var base_hit_damage: float = power_for_hit * dynamic_potency

			if is_crit:
				print("Critical Hit!")
				var crit_bonus: float = 0.0
				crit_bonus = attacker.get_crit_damage_bonus()
				base_hit_damage *= (1.0 + crit_bonus)

			var final_dmg_float = float(base_hit_damage)
			var def_mod = 1.0 if not target.is_breached else 0.5

			if damage_type == Action.DamageType.KINETIC:
				final_dmg_float *= (1.0 - float(target.current_stats.kinetic_defense * def_mod) / 100)
			elif damage_type == Action.DamageType.ENERGY:
				final_dmg_float *= (1.0 - float(target.current_stats.energy_defense * def_mod) / 100)

			final_dmg_float *= attacker.get_damage_dealt_scalar()
			final_dmg_float *= target.get_damage_taken_scalar()
			var final_damage = max(0, int(final_dmg_float))

			await target.apply_one_hit(final_damage, self, attacker, is_crit)
			await _process_on_hit_triggers(attacker, target, battle_manager)

			if random and target.is_defeated:
				final_targets.remove_at(t)

			if hit_count > 1 and i < hit_count - 1:
				await battle_manager.wait(0.25)
		if random: break
		var context = { "attacker": attacker, "targets": [self] }
		await target._fire_condition_event(Trigger.TriggerType.AFTER_BEING_ATTACKED, context)

	return

func get_dynamic_potency(attacker: ActorCard, _target: ActorCard, focus_cost: int) -> float:
	if potency_per_focus > 0.0:
		var focus_pips = 0
		if attacker is HeroCard:
			focus_pips = attacker.current_focus
		return potency + potency_per_focus * focus_pips

	if potency_scalar_per_focus > 0.0:
		var remaining_focus = 0
		if attacker is HeroCard:
			remaining_focus = max(0, attacker.current_focus - focus_cost)

		return potency * (1.0 + (potency_scalar_per_focus * remaining_focus))

	return potency

func _get_pre_hit_triggers(attacker: ActorCard, target: ActorCard) -> Dictionary:
	var context = {}
	for trigger in pre_hit_triggers:
		var condition_met = false

		match trigger.condition:
			PreHitTrigger.PreHitCondition.ALWAYS:
				condition_met = true

			PreHitTrigger.PreHitCondition.IF_TARGET_HAS_CONDITION:
				if target.has_condition(trigger.string_context):
					condition_met = true

			PreHitTrigger.PreHitCondition.IF_TARGET_HAS_ANY_DEBUFF:
				if target.count_debuffs() > 0:
					condition_met = true
		if condition_met:
			for effect in trigger.effects_to_run:
				effect.execute(context, attacker, target)
	return context

func _process_on_hit_triggers(attacker: ActorCard, target: ActorCard, battle_manager: BattleManager) -> void:
	for hit_trigger in on_hit_triggers:
		var condition_met = false

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
				if effect is Effect_Damage:
					await battle_manager.wait(0.25)
				await battle_manager.execute_triggered_effect(attacker, effect, [target], null)
