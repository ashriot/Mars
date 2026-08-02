extends ActionEffect
class_name Effect_RecoverBreach

@export var effect_target_type: Action.TargetType = Action.TargetType.SELF

func execute(attacker: BattleCombatant, primary_targets: Array[BattleCombatant], battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	var targets: Array[BattleCombatant] = battle_manager.get_targets(
		effect_target_type, attacker.is_hero(), primary_targets, attacker,
	)

	for target: BattleCombatant in targets:
		if target.is_breached:
			await target.recover_breach()
			print(target.actor_name, " spends turn recovering guard.")

	await battle_manager.wait()
