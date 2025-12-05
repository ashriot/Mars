# src/data/Trait.gd
extends Resource
class_name Trait

@export var trait_name: String = "New Trait"
@export_multiline var description_template: String = "Increases effect by {val}%."

# --- UI HELPER ---
# Allows the UI to show "Current: +10%" vs "Next: +20%"
func get_description(_rank: int) -> String:
	# Child classes can override this to do math (e.g. level * 10)
	# and replace "{val}" in the template.
	return description_template

# --- VIRTUAL HOOKS (Stateless Logic) ---

# 1. Stat Modifiers
func get_stat_mod(_stat: ActorStats.Stats, _rank: int) -> int:
	return 0

# 2. Damage Modifiers
func get_damage_dealt_scalar(_target: ActorCard) -> float:
	return 0.0

func get_damage_taken_scalar(_attacker: ActorCard, _rank: int) -> float:
	return 0.0

# 3. Event Triggers
func on_trigger(_trigger_type: Trigger.TriggerType, _context: Dictionary, _owner: ActorCard, _rank: int):
	pass
