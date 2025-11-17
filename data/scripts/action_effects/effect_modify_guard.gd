extends ActionEffect
class_name Effect_ModifyGuard

@export var guard_amount: int = 1

func execute(_attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	print("--- Executing Change Guard Effect ---")
	for target_actor in parent_targets:
		if target_actor and is_instance_valid(target_actor) and not target_actor.is_defeated:
			print(target_actor.actor_name, " gains ", guard_amount, " Guard.")
			target_actor.modify_guard(guard_amount)

	await battle_manager.wait(0.1)
	return
