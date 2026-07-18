extends ActionEffect
class_name Effect_Healing

@export var potency: float = 1.0
@export var power_type: Action.PowerType = Action.PowerType.PSYCHE
@export var focus_scalar: float = 0.0
@export var scales_with_missing_hp: bool = false
@export var is_revive: bool = true


func execute(attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:

	print("--- Executing Healing Effect ---")

	if parent_targets.is_empty():
		print("Healing effect had no targets.")
		return

	for target in parent_targets:
		if not target or not is_instance_valid(target):
			continue
		var actor_target := target as ActorCard
		if actor_target == null or (actor_target.is_defeated and not is_revive):
			continue

		var base_power = attacker.get_power(power_type)
		var base_heal_float: float = base_power * potency

		var scalar: float = 1.0
		if scales_with_missing_hp:
			var hp_percent := float(actor_target.current_hp) / maxf(
				actor_target.current_stats.max_hp, 1,
			)
			scalar += (1.0 - hp_percent)

		if focus_scalar != 0.0 and actor_target is HeroCard:
			scalar += focus_scalar * (actor_target as HeroCard).current_focus

		var final_heal_float = base_heal_float * scalar
		var final_heal_int = roundi(final_heal_float)

		print(actor_target.actor_name, " is healed for ", final_heal_int)
		actor_target.take_healing(final_heal_int, is_revive)

	await battle_manager.wait()
	return
