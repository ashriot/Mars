# Effect_GrantGuard.gd
extends ActionEffect
class_name Effect_GrantGuard

@export var guard_amount: int = 1

func execute(attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, _action: Action = null) -> void:
	print("--- Executing Grant Guard Effect ---")

	var final_targets = battle_manager.get_targets(
		target_type,
		attacker is HeroCard,
		parent_targets
	)

	match target_type:
		Action.TargetType.PARENT:
			final_targets = parent_targets

		Action.TargetType.SELF:
			final_targets.append(attacker)

		Action.TargetType.LEAST_GUARD_ALLY:
			var allies = battle_manager.get_living_heroes()
			if allies.is_empty(): return

			var target_ally: ActorCard = allies[0]
			for ally in allies:
				if ally.current_guard < target_ally.current_guard:
					target_ally = ally
			final_targets.append(target_ally)

		Action.TargetType.ALL_ALLIES:
			for hero in battle_manager.get_living_heroes():
				final_targets.append(hero)

		Action.TargetType.ALL_ENEMIES:
			for enemy in battle_manager.get_living_enemies():
				final_targets.append(enemy)

	if final_targets.is_empty():
		print("Grant Guard effect had no targets.")
		return

	for target_actor in final_targets:
		if target_actor and is_instance_valid(target_actor) and not target_actor.is_defeated:
			print(target_actor.actor_name, " gains ", guard_amount, " Guard.")
			target_actor.gain_guard(guard_amount)

	await battle_manager.wait(0.1)
	return
