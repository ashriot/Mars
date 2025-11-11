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
	var random = false
	if action.target_type == Action.TargetType.RANDOM_ENEMY:
		random = true
		primary_targets = battle_manager.get_living_enemies()
		if primary_targets.is_empty():
			print("RANDOM_ENEMY: No living enemies to target!")
			return

	var target = null
	for t in primary_targets.size():
		for i in hit_count:
			if random:
				target = primary_targets.pick_random()
			else:
				target = primary_targets[t]
			var dynamic_potency = get_dynamic_potency(attacker, target, action.focus_cost)

			if not target or not is_instance_valid(target):
				continue

			if target.is_defeated:
				break

			await target.apply_one_hit(self, attacker, dynamic_potency)

			if hit_count > 1 and i < hit_count - 1:
				await battle_manager.wait(0.25)
		if random: break

	return

func get_dynamic_potency(attacker: ActorCard, _target: ActorCard, focus_cost: int) -> float:
	if potency_per_focus > 0.0:
		var focus_pips = 0
		if attacker is HeroCard:
			focus_pips = attacker.current_focus_pips
		return potency_per_focus * focus_pips

	if potency_scalar_per_focus > 0.0:
		var remaining_focus = 0
		if attacker is HeroCard:
			remaining_focus = max(0, attacker.current_focus_pips - focus_cost)

		return potency * (1.0 + (potency_scalar_per_focus * remaining_focus))

	return potency
