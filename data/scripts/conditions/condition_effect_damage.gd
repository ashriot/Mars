extends ConditionEffect
class_name ConditionEffect_Damage

@export var potency: float = 1.0
@export var power_type: Action.PowerType = Action.PowerType.PSYCHE
@export var damage_type: Action.DamageType = Action.DamageType.PIERCING

func execute(attacker: ActorCard, primary_targets: Array, battle_manager: BattleManager) -> void:

	for target in primary_targets:
		if not target or not is_instance_valid(target) or target.is_defeated:
			continue

		# 1. Get Power
		var power_for_hit = attacker.get_power(power_type)

		# 2. Get Base Damage (no Overload, no Focus)
		var base_hit_damage: float = power_for_hit * potency

		# 3. Apply Defenses (we can just call the helper)
		var final_damage_float = target.calculate_damage_with_defense(
			base_hit_damage,
			damage_type,
			target.is_breached # (We just check their current state)
		)

		# 4. Apply the hit
		await target.apply_one_hit_simple(roundi(final_damage_float), damage_type)

	return
