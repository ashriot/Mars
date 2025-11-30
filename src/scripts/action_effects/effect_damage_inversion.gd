extends Effect_Damage
class_name Effect_Damage_Inversion

@export var remove_guard_gained: bool = false

func _get_dynamic_hit_count(_attacker: ActorCard, _target: ActorCard, context: Dictionary = {}) -> int:
	var guard_gained = 0
	if context.has("guard_gained"):
		guard_gained = context.guard_gained
	else:
		push_error("Inversion effect triggered without 'guard_gained' context!")

	return guard_gained
