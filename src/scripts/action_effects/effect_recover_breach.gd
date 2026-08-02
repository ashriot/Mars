extends ActionEffect
class_name Effect_RecoverBreach

@export var effect_target_type: Action.TargetType = Action.TargetType.SELF

func execute(attacker_node: Node, primary_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	var attacker := BattleCombatant.resolve_model(attacker_node)

	var targets = battle_manager.get_targets(
		effect_target_type, attacker.is_hero(), primary_targets, attacker_node,
	)

	for target_node: Node in targets:
		var target := BattleCombatant.resolve_model(target_node)
		if target.is_breached:
			await target.recover_breach()
			print(target.actor_name, " spends turn recovering guard.")

	await battle_manager.wait()
