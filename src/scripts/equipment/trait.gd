extends Resource
class_name Trait

@export var trait_name: String = "New Trait"
@export_multiline var description: String = ""

# --- RUNTIME STATE ---
# This is injected by the HeroCard when the battle starts
var current_tier: int = 1

# ===================================================================
# VIRTUAL HOOKS (Override these in child scripts)
# ===================================================================

# 1. Stat Modifiers (e.g. +5 SPD per Tier)
func get_stat_mod(_stat: ActorStats.Stats) -> int:
	return 0

# 2. Damage Modifiers (e.g. Relentlessness: +Dmg vs Breached)
func get_damage_dealt_scalar(_target: ActorCard) -> float:
	return 0.0

func get_damage_taken_scalar(_attacker: ActorCard) -> float:
	return 0.0

# 3. Event Triggers (e.g. Shattering Blow: Effect on Breach)
# We reuse your existing TriggerType enum for consistency
func on_trigger(_trigger_type: Trigger.TriggerType, _context: Dictionary, _owner: ActorCard):
	pass
