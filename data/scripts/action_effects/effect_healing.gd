extends ActionEffect
class_name Effect_Healing

@export var potency: float = 1.0
@export var power_type: Action.PowerType = Action.PowerType.PSYCHE
@export var drain_focus_scalar: float = 0.0
@export var scales_with_missing_hp: bool = false
@export var is_revive: bool = true


func execute(attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, _action: Action = null) -> void:

	print("--- Executing Healing Effect ---")

	if parent_targets.is_empty():
		print("Healing effect had no targets.")
		return

	for target in parent_targets:
		if not target or not is_instance_valid(target) or (target.is_defeated and not is_revive):
			continue
		target = target as HeroCard

		var base_power = attacker.get_power(power_type)
		var base_heal_float: float = base_power * potency

		var scalar: float = 1.0
		if scales_with_missing_hp:
			var hp_percent = float(target.current_hp) / target.current_stats.max_hp
			scalar += (1.0 - hp_percent)

		scalar += drain_focus_scalar * target.current_focus

		var final_heal_float = base_heal_float * scalar
		var final_heal_int = roundi(final_heal_float)

		print(target.actor_name, " is healed for ", final_heal_int)
		target.take_healing(final_heal_int, is_revive)
		if drain_focus_scalar > 0.0:
			target.modify_focus(-target.current_focus)

	await battle_manager.wait()
	return
