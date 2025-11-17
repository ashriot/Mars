extends Resource
class_name ActionEffect

@export var target_type: Action.TargetType = Action.TargetType.PARENT

func execute(_attacker: ActorCard, _parent_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	await battle_manager.wait()
	pass
