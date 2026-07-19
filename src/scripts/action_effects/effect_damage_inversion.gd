extends Effect_Damage
class_name Effect_Damage_Inversion

@export_range(0, 99, 1) var max_guard_points: int = 0

func _resolve_hit_count(_attacker: ActorCard, context: Dictionary = {}) -> int:
	if not context.has("guard_gained"):
		push_error("Inversion effect triggered without 'guard_gained' context!")
		return 0

	var guard_gained := maxi(0, int(context["guard_gained"]))
	return mini(guard_gained, max_guard_points) if max_guard_points > 0 else guard_gained
