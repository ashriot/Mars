extends ActionEffect
class_name Effect_ModifyFocus

@export var focus_amount: int = 1

func execute(attacker: BattleCombatant, targets: Array[BattleCombatant], battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	print("--- Executing Change Guard Effect ---")
	var final_targets := battle_manager.get_targets(
		target_type,
		attacker.is_hero(),
		targets,
		attacker,
	)

	for target_actor: BattleCombatant in final_targets:
		if target_actor.is_defeated or not target_actor is HeroCombatant:
			continue
		print(target_actor.actor_name, " gains ", focus_amount, " Focus.")
		await (target_actor as HeroCombatant).modify_focus(focus_amount)

	await battle_manager.wait(0.1)
	return
