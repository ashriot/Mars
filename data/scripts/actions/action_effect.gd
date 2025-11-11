extends Resource
class_name ActionEffect

func execute(_attacker: ActorCard, _primary_targets: Array, battle_manager: BattleManager, _action: Action) -> void:
	await battle_manager.wait(0.1)
	pass
