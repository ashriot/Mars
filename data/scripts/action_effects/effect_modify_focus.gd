extends ActionEffect
class_name Effect_ModifyFocus

@export var focus_amount: int = 1

func execute(attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, _action: Action = null) -> void:
	print("--- Executing Change Guard Effect ---")

	var final_targets = battle_manager.get_targets(
		target_type,
		attacker is HeroCard,
		parent_targets
	)

	for target_actor in final_targets:
		if target_actor and is_instance_valid(target_actor) and not target_actor.is_defeated:
			print(target_actor.actor_name, " gains ", focus_amount, " Focus.")
			target_actor.modify_focus(focus_amount)

	await battle_manager.wait(0.1)
	return
