# src/data/Trait.gd
extends Resource
class_name Trait

@export var trait_name: String = "New Trait"
@export_multiline var description_template: String = "Increases effect by {val}%."
var current_tier := 1

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
func get_damage_dealt_modifier(target_node: Node) -> float:
	BattleCombatant.resolve_model(target_node)
	return 0.0

func get_damage_taken_modifier(attacker_node: Node) -> float:
	BattleCombatant.resolve_model(attacker_node)
	return 0.0

func get_action_ct_multiplier(_action: Action) -> float:
	return 1.0

# 3. Event Triggers
func on_trigger(
	_trigger_type: Trigger.TriggerType,
	_context: Dictionary,
	owner_node: Node,
	_rank: int,
) -> void:
	BattleCombatant.resolve_model(owner_node)
	pass
