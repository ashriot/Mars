extends ActionEffect
class_name Effect_ModifyGuard

@export var guard_amount: int = 1
@export var percent_change: float = 0.0
@export_range(0, 99, 1) var max_abs_change: int = 0


func resolve_guard_delta(current_guard: int) -> int:
	var delta := floori(float(current_guard) * percent_change) \
		if not is_zero_approx(percent_change) else guard_amount
	if max_abs_change > 0:
		delta = clampi(delta, -max_abs_change, max_abs_change)
	return delta


func execute(_attacker: BattleCombatant, parent_targets: Array[BattleCombatant], battle_manager: BattleManager, _action: Action = null, _context: Dictionary = {}) -> void:
	print("--- Executing Change Guard Effect ---")
	var targets: Array[BattleCombatant] = []
	for target: BattleCombatant in parent_targets:
		if is_instance_valid(target):
			targets.append(target)
	for target_actor: BattleCombatant in targets:
		if target_actor.is_defeated:
			continue
		await target_actor.modify_guard(resolve_guard_delta(target_actor.current_guard))

	await battle_manager.wait(0.1)
	return
