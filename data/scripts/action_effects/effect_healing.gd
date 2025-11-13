# Effect_Healing.gd
extends ActionEffect
class_name Effect_Healing

# --- This effect's unique data ---
@export var potency: float = 1.0
@export var power_type: Action.PowerType = Action.PowerType.PSYCHE
@export var scales_with_missing_hp: bool = false
@export var is_revive: bool = false


func execute(attacker: ActorCard, primary_targets: Array, battle_manager: BattleManager, _action: Action = null) -> void:

	print("--- Executing Healing Effect ---")

	if primary_targets.is_empty():
		print("Healing effect had no targets.")
		return

	# --- 1. Loop through the targets this effect was given ---
	for target in primary_targets:
		# Check for "is_revive" logic
		if not target or not is_instance_valid(target) or (target.is_defeated and not is_revive):
			continue # Skip dead or invalid targets

		# 2. Calculate the base heal amount
		var base_power = attacker.get_power(power_type)
		var base_heal_float: float = base_power * potency

		# 3. Calculate your "Missing HP" scalar
		var scalar: float = 1.0
		if scales_with_missing_hp:
			var hp_percent = float(target.current_hp) / target.current_stats.max_hp
			scalar += (1.0 - hp_percent)

		# 4. Calculate the final, rounded heal
		var final_heal_float = base_heal_float * scalar
		var final_heal_int = roundi(final_heal_float)

		# 5. Call the target's "take_healing" function
		print(target.actor_name, " is healed for ", final_heal_int)
		target.take_healing(final_heal_int, is_revive)

	# 6. Wait for the effect to register
	await battle_manager.wait(0.01)
	return
