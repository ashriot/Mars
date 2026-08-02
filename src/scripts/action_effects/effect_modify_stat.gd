extends ActionEffect
class_name Effect_ModifyStat

@export var stat: ActorStats.Stats
@export var mod: int = 0
@export var scalar: float = 0.0

func execute(_attacker: BattleCombatant, targets: Array[BattleCombatant], battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	for target_combatant: BattleCombatant in targets:
		var target := target_combatant as HeroCombatant
		if target == null:
			continue
		if mod > 0:
			target.stat_mods.get_or_add()
		if scalar > 0.0:
			target.stat_scalars.get_or_add()

	battle_manager.update_turn_order()
	await battle_manager.wait(0.01)
