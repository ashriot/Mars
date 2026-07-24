extends Effect_Damage
class_name Effect_Damage_Inversion

@export_range(0, 99, 1) var max_guard_points: int = 0


func resolve_guard_points(current_guard: int) -> int:
	var available_guard := maxi(0, current_guard)
	return mini(available_guard, max_guard_points) \
		if max_guard_points > 0 else available_guard


func _resolve_hit_count(_attacker: ActorCard, context: Dictionary = {}) -> int:
	if not context.has("guard_destroyed"):
		return hit_count

	return maxi(0, int(context["guard_destroyed"]))


func execute(
	attacker: ActorCard,
	parent_targets: Array,
	battle_manager: BattleManager,
	action: Action = null,
	context: Dictionary = {},
) -> void:
	for target: ActorCard in parent_targets:
		if not is_instance_valid(target) or target.is_defeated:
			continue
		var guard_destroyed := resolve_guard_points(target.current_guard)
		if guard_destroyed <= 0:
			continue
		await target.modify_guard(-guard_destroyed)
		var damage_context := context.duplicate()
		damage_context["guard_destroyed"] = guard_destroyed
		await super.execute(
			attacker,
			[target],
			battle_manager,
			action,
			damage_context,
		)
