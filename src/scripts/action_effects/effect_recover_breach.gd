extends ActionEffect
class_name Effect_RecoverBreach

@export var effect_target_type: Action.TargetType = Action.TargetType.SELF

func execute(attacker: ActorCard, primary_targets: Array, battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:

	var targets = battle_manager.get_targets(effect_target_type, attacker is HeroCard, primary_targets, attacker)

	for target in targets:
		if target.is_breached:
			target.recover_breach()
			print(target.actor_name, " spends turn recovering guard.")

	await battle_manager.wait()
