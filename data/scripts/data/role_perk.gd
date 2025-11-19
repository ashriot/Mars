extends Resource
class_name RolePerk

@export var perk_id: String = "personal_shield"
@export var perk_name: String = "Personal Shield"
@export_multiline var description: String = "Asher gains 1 Guard for every 4 Focus he spends in combat."
@export var icon: Texture

# What type of perk is this?
enum PerkType {
	PASSIVE_STAT_BOOST,    # Permanent stat increase
	COMBAT_TRIGGER,        # Triggers on certain conditions (e.g., "on Focus spent")
	CONDITIONAL_BONUS,     # Bonus under certain conditions (e.g., "while Breached")
	SPECIAL_MECHANIC       # Unique scripted behavior
}

@export var perk_type: PerkType = PerkType.PASSIVE_STAT_BOOST

# For stat boost perks
@export var stat_boost_type: ActorStats.Stats
@export var stat_boost_amount: int = 0

# For combat trigger perks (scripted behavior)
@export var trigger_script: GDScript  # Custom script that handles the perk logic

# Optional: Conditions for when this perk is active
@export var requires_role: String = ""  # e.g., "gunslinger" - only active in this role
@export var is_combat_only: bool = true

# Example perk data that your combat system can read
@export var perk_data: Dictionary = {}
# Examples:
# {"guard_per_focus": 4} for Personal Shield
# {"damage_bonus_per_debuff": 15} for Exploit Weakness scaling
# {"piercing_damage": 25} for Acid Rounds
