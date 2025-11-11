# Effect_Damage.gd
extends ActionEffect
class_name Effect_Damage

# --- Base Damage Properties ---
@export var potency: float = 1.0
@export var hit_count: int = 1
@export var power_type: Action.PowerType = Action.PowerType.ATTACK
@export var damage_type: Action.DamageType = Action.DamageType.KINETIC

# --- NEW: Focus Scaling Properties ---
# (As you said, default to 0.0 so they are ignored)

# This is for "potency *per* focus pip" (e.g., Focused Bolt)
@export var potency_per_focus: float = 0.0

# This is for "potency *scaled by* remaining focus"
@export var potency_scalar_per_focus: float = 0.0


func execute(attacker: ActorCard, primary_targets: Array, battle_manager: BattleManager, action: Action) -> void:

	print("\n--- Executing Damage Effect for ", hit_count, " hit(s) ---")

	for target in primary_targets:
		if not target or not is_instance_valid(target):
			continue # Skip invalid targets

		# --- 1. Get Dynamic Potency ---
		# We calculate this *once* per target, before the hit loop.
		var dynamic_potency = get_dynamic_potency(attacker, target, action.focus_cost)

		# --- 2. Loop for each hit ---
		for i in hit_count:
			if target.is_defeated:
				break # Stop hitting a dead target

			# --- 3. Tell the target to "get hit" ---
			# We pass the calculated potency and all other data.
			# The "await" is now here, inside the loop.
			await target.apply_one_hit(self, attacker, dynamic_potency)

			# --- 4. Pause for multi-hit ---
			if hit_count > 1 and i < hit_count - 1:
				await battle_manager.wait(0.25)

	return

# ===================================================================
# THE "DYNAMIC POTENCY" FUNCTION (This is what you asked for)
# ===================================================================
# This is called by this script's own 'execute' function.
func get_dynamic_potency(attacker: ActorCard, target: ActorCard, focus_cost: int) -> float:

	# --- 1. "potency_per_focus" (e.g., Focused Bolt) ---
	# This *replaces* the base potency.
	if potency_per_focus > 0.0:
		var focus_pips = 0
		if attacker is HeroCard:
			focus_pips = attacker.current_focus_pips

		# Formula: (0.25 * 4 pips) = 1.0 potency
		return potency_per_focus * focus_pips

	# --- 2. "potency_scalar_per_focus" (e.g., Echo's Psionic Storm) ---
	# This *modifies* the base potency.
	if potency_scalar_per_focus > 0.0:
		var remaining_focus = 0
		if attacker is HeroCard:
			# Calculate remaining focus *after* spending the cost
			remaining_focus = max(0, attacker.current_focus_pips - focus_cost)

		# Formula: 1.0 * (1.0 + (0.1 * 3 pips)) = 1.3 potency
		return potency * (1.0 + (potency_scalar_per_focus * remaining_focus))

	# --- 3. Default ---
	# If no special scaling, just return the base potency.
	return potency
