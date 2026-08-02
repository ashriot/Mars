# Effect_SwapResources.gd
extends ActionEffect
class_name Effect_SwapResources

# --- 1. Define the resources we can swap ---
# We'll use a simple enum for this
enum SwappableResource {
	FOCUS,
	GUARD
	# (You could add HP, CT, etc. later)
}

# --- 2. Define our "swap" variables ---
@export var resource_a: SwappableResource = SwappableResource.GUARD
@export var resource_b: SwappableResource = SwappableResource.FOCUS
# (effect_target_type is inherited and defaults to PRIMARY)

func execute(attacker_node: Node, primary_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:

	print("--- Executing Resource Swap Effect ---")
	BattleCombatant.resolve_model(attacker_node)
	var targets := BattleCombatant.resolve_models(primary_targets)

	for target: BattleCombatant in targets:
		var hero_target := target as HeroCombatant
		if hero_target == null:
			continue

		# A. Get the current values
		var guard_val = hero_target.current_guard
		var focus_val = hero_target.current_focus

		# B. Calculate the *difference*
		var guard_to_add = focus_val - guard_val
		var focus_to_add = guard_val - focus_val

		# C. Call the "modify" functions
		# (This assumes you have these functions)
		await hero_target.modify_guard(guard_to_add)
		await hero_target.modify_focus(focus_to_add)

		print(hero_target.actor_name, " swapped Guard (", guard_val, ") with Focus (", focus_val, ")")

	await battle_manager.wait()
	return
