extends ActionEffect
class_name Effect_ModifyCT

@export var ct_change_percent: float = 0.5

func execute(_attacker: BattleCombatant, targets: Array[BattleCombatant], battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	for target: BattleCombatant in targets:
		var ct_change := int(battle_manager.TARGET_CT * ct_change_percent)
		target.current_ct += ct_change
	battle_manager.update_turn_order()
	await battle_manager.wait()
