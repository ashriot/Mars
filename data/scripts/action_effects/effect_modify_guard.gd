extends ActionEffect
class_name Effect_ModifyGuard

@export var guard_amount: int = 1
@export var percent_change: float = 0.0

func execute(_attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	print("--- Executing Change Guard Effect ---")
	for target_actor in parent_targets:
		if target_actor and not target_actor.is_defeated:
			if percent_change != 0.0:
				var guard = floori(target_actor.current_guard * percent_change)
				await target_actor.modify_guard(guard)
			else:
				await target_actor.modify_guard(guard_amount)

	await battle_manager.wait(0.1)
	return
