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


func execute(attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, action: Action = null) -> void:
	var final_targets: Array = []
	match target_type:
		Action.TargetType.PARENT:
			final_targets = parent_targets
		Action.TargetType.ALL_ENEMIES:
			if attacker is HeroCard:
				for enemy in battle_manager.get_living_enemies():
					final_targets.append(enemy)
			else:
				for hero in battle_manager.get_living_heroes():
					final_targets.append(hero)

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

	var target = null
	for t in final_targets.size():
		for i in hit_count:
			if random:
				target = final_targets.pick_random() as ActorCard
			else:
				target = final_targets[t]
			var dynamic_potency = get_dynamic_potency(attacker, target, focus_cost)

			if not target or not is_instance_valid(target):
				continue

			if target.is_defeated and not random:
				break
			if split_damage: dynamic_potency /= final_targets.size()
			await target.apply_one_hit(self, attacker, dynamic_potency)
			await _process_on_hit_triggers(attacker, target, battle_manager)

			if random and target.is_defeated:
				final_targets.remove_at(t)

			if hit_count > 1 and i < hit_count - 1:
				await battle_manager.wait(0.25)
		if random: break

	return

func get_dynamic_potency(attacker: ActorCard, _target: ActorCard, focus_cost: int) -> float:
	if potency_per_focus > 0.0:
		var focus_pips = 0
		if attacker is HeroCard:
			focus_pips = attacker.current_focus
		return potency_per_focus * focus_pips

	if potency_scalar_per_focus > 0.0:
		var remaining_focus = 0
		if attacker is HeroCard:
			remaining_focus = max(0, attacker.current_focus - focus_cost)

		return potency * (1.0 + (potency_scalar_per_focus * remaining_focus))

	return potency

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
