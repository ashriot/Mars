extends Resource
class_name ConditionEffect

func execute(_attacker: ActorCard, _primary_targets: Array, battle_manager: BattleManager) -> void:
	await battle_manager.wait(0.01)
	pass
