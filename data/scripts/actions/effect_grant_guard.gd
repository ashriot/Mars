# Effect_GrantGuard.gd
extends ActionEffect
class_name Effect_GrantGuard

enum EffectTarget {
	PRIMARY, # The target(s) the player clicked
	SELF,
	LEAST_GUARD_ALLY,
	ALL_ALLIES,
	ALL_ENEMIES
}

@export var guard_amount: int = 1
# --- 2. RENAMED VARIABLE ---
@export var effect_target_type: EffectTarget = EffectTarget.SELF


func execute(attacker: ActorCard, primary_targets: Array, battle_manager: BattleManager, action: Action) -> void:

	print("--- Executing Grant Guard Effect ---")

	# --- 3. BUILD THE "FINAL" TARGET LIST ---
	var final_targets: Array[ActorCard] = []

	match effect_target_type:
		EffectTarget.PRIMARY:
			# This effect *uses* the player's clicked target(s)
			final_targets = primary_targets

		EffectTarget.SELF:
			final_targets.append(attacker)

		EffectTarget.LEAST_GUARD_ALLY:
			var allies = battle_manager.get_living_heroes()
			if allies.is_empty():
				return # No one to buff

			var target_ally: ActorCard = allies[0]
			for ally in allies:
				if ally.current_guard < target_ally.current_guard:
					target_ally = ally
			final_targets.append(target_ally)

		EffectTarget.ALL_ALLIES:
			for hero in battle_manager.get_living_heroes():
				final_targets.append(hero)

		EffectTarget.ALL_ENEMIES:
			for enemy in battle_manager.get_living_enemies():
				final_targets.append(enemy)

	# --- 4. Loop through the *final* list and apply the effect ---
	if final_targets.is_empty():
		print("Grant Guard effect had no targets.")
		return

	for target_actor in final_targets:
		if target_actor and is_instance_valid(target_actor) and not target_actor.is_defeated:
			print(target_actor.actor_name, " gains ", guard_amount, " Guard.")
			target_actor.gain_guard(guard_amount)

	await battle_manager.wait(0.1)
	return
