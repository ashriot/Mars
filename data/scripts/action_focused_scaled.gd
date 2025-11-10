extends Action
class_name ActionFocusScaled

@export var potency_per_focus: float = 0.25
@export var scalar_per_remaining_focus: float = 0.0

func get_dynamic_potency(attacker: ActorCard, defender: ActorCard) -> float:
	var focus_pips = 0
	if attacker is HeroCard:
		focus_pips = attacker.current_focus_pips
	var scalar = 1.0 + scalar_per_remaining_focus * focus_pips

	var new_potency = potency_per_focus * focus_pips * scalar

	return new_potency
