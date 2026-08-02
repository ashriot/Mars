extends ActionEffect
class_name Effect_ModifyCT

@export var ct_change_percent: float = 0.5

func execute(attacker_node: Node, parent_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	BattleCombatant.resolve_model(attacker_node)
	for target_node: Node in parent_targets:
		var target := BattleCombatant.resolve_model(target_node)
		var ct_change := int(battle_manager.TARGET_CT * ct_change_percent)
		target.current_ct += ct_change
	battle_manager.update_turn_order()
	await battle_manager.wait()
