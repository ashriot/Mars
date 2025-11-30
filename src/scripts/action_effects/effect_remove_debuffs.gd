extends Effect_RemoveCondition
class_name Effect_RemoveDebuffs

@export var quantity: int = 1


func execute(_attacker: ActorCard, targets: Array, _battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	for target in targets:
		target.remove_debuffs(quantity)
