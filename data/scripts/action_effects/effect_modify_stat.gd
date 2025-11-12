extends ActionEffect
class_name Effect_ModifyStat

@export var stat: ActorStats.Stats
@export var mod: int = 0
@export var scalar: float = 0.0

func execute(_attacker: ActorCard, primary_targets: Array, battle_manager: BattleManager, _action: Action = null) -> void:
	for target in primary_targets:
		target = target as HeroCard
		if mod > 0:
			target.stat_mods.get_or_add()
		if scalar > 0.0:
			target.stat_scalars.get_or_add()

	battle_manager.update_turn_order()
	await battle_manager.wait(0.01)
