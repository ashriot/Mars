extends ActionEffect
class_name Effect_RecoverBreach

@export var effect_target_type: Action.TargetType = Action.TargetType.SELF

func execute(attacker_node: Node, primary_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	var attacker := BattleCombatant.resolve_model(attacker_node)
	var primary_target_models := BattleCombatant.resolve_models(primary_targets)

	var targets := BattleCombatant.resolve_models(battle_manager.get_targets(
		effect_target_type, attacker.is_hero(), primary_target_models, attacker,
	))

	for target: BattleCombatant in targets:
		if target.is_breached:
			await target.recover_breach()
			print(target.actor_name, " spends turn recovering guard.")

	await battle_manager.wait()
