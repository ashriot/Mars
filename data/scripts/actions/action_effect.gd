extends Resource
class_name ActionEffect

enum EffectTarget {
	PRIMARY, # The target(s) the player clicked
	SELF,
	LEAST_GUARD_ALLY,
	ALL_ALLIES,
	ALL_ENEMIES
}

func execute(_attacker: ActorCard, _primary_targets: Array, battle_manager: BattleManager, _action: Action = null) -> void:
	await battle_manager.wait(0.1)
	pass
