extends ActionEffect
class_name Effect_ModifyCT

# 0.5 = 50% boost
@export var ct_boost_percent: float = 0.5

func execute(_attacker: ActorCard, parent_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	for target in parent_targets:
		var ct_to_add = int(battle_manager.TARGET_CT * ct_boost_percent)
		target.current_ct += ct_to_add
		print(target.actor_name, " CT boosted by ", ct_to_add)

	battle_manager.update_turn_order()
	await battle_manager.wait()
