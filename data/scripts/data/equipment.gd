extends Resource
class_name Equipment

enum Slot { WEAPON, ARMOR, ACCESSORY }
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var equipment_id: String = ""
@export var item_name: String = ""
@export var slot: Slot = Slot.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture

# Current level (1-20 for standard progression, can go beyond for post-game)
@export var level: int = 1
@export var max_level: int = 20

# Stat Ranks (1-5 scale, like enemies)
# Weapons focus on: ATK, PSY, OVR, SPD, PRC
# Armor focuses on: HP, GRD, SPD, KIN_DEF, NRG_DEF
@export_group("Stat Ranks")
@export var hp_rank: int = 0
@export var guard_rank: int = 0
@export var attack_rank: int = 0
@export var psyche_rank: int = 0
@export var overload_rank: int = 0
@export var speed_rank: int = 0
@export var aim_rank: int = 0  # Stored as percentage (e.g., 15 = 15%)
@export var kinetic_defense_rank: int = 0  # Stored as percentage
@export var energy_defense_rank: int = 0  # Stored as percentage

# Special properties (like Advantage, Fortified, etc.)
@export_group("Special Effects")
@export var special_effect: String = ""  # e.g., "advantage_1", "fortified"
@export var special_effect_value: int = 0  # e.g., +1 Focus for Advantage

# Upgrade costs
@export_group("Upgrade System")
@export var bits_to_upgrade: int = 50  # Cost increases per level
@export var can_upgrade: bool = true

func calculate_stats() -> ActorStats:
	var stats = ActorStats.new()
	var multiplier = _get_multiplier()

	stats.max_hp = _calc_stat(hp_rank, multiplier) * 5 if hp_rank > 0 else 0
	stats.starting_guard = guard_rank  # Guard is flat, not scaled
	stats.attack = _calc_stat(attack_rank, multiplier) if attack_rank > 0 else 0
	stats.psyche = _calc_stat(psyche_rank, multiplier) if psyche_rank > 0 else 0
	stats.overload = _calc_stat(overload_rank, multiplier) if overload_rank > 0 else 0
	stats.speed = _calc_stat(speed_rank, _get_multiplier(4)) if speed_rank > 0 else 0

	# Guard formula: INT(level/10) + rank + 2
	stats.starting_guard = int(level / 10) + guard_rank + 2 if guard_rank > 0 else 0

	# aim formula: (level/4) + (rank * 5)
	stats.aim = int(level / 4.0) + (aim_rank * 5) if aim_rank > 0 else 0

	# Kinetic Defense formula: (level/2) + (rank * 15) - 10
	stats.kinetic_defense = int(level / 2.0) + (kinetic_defense_rank * 15) - 10 if kinetic_defense_rank > 0 else 0

	# Energy Defense formula: (level/2) + (rank * 15) - 10
	stats.energy_defense = int(level / 2.0) + (energy_defense_rank * 15) - 10 if energy_defense_rank > 0 else 0

	# Clamp defenses and aim to valid ranges
	stats.aim = clampi(stats.aim, 0, 75)
	stats.kinetic_defense = clampi(stats.kinetic_defense, 0, 90)
	stats.energy_defense = clampi(stats.energy_defense, 0, 90)

	return stats

func _get_multiplier(base: int = 5) -> float:
	return int(pow((level + base), 2) * 0.048)

func _calc_stat(rank: int, multiplier: float) -> int:
	return int(((rank + 5) * multiplier))

func get_upgrade_cost() -> int:
	if level >= max_level:
		return 0
	# Cost increases with level (example: base cost * level)
	return bits_to_upgrade * level

func upgrade() -> bool:
	if level >= max_level or not can_upgrade:
		return false
	level += 1
	return true

func get_stat_preview_at_level(target_level: int) -> ActorStats:
	# Preview stats at a future level (for UI display)
	var original_level = level
	level = target_level
	var preview = calculate_stats()
	level = original_level
	return preview

func get_stat_gain_on_upgrade() -> Dictionary:
	# Returns the stat difference between current and next level
	var current = calculate_stats()
	var next = get_stat_preview_at_level(level + 1)

	return {
		"hp": next.max_hp - current.max_hp,
		"guard": next.starting_guard - current.starting_guard,
		"attack": next.attack - current.attack,
		"psyche": next.psyche - current.psyche,
		"overload": next.overload - current.overload,
		"speed": next.speed - current.speed,
		"aim": next.aim - current.aim,
		"kinetic_defense": next.kinetic_defense - current.kinetic_defense,
		"energy_defense": next.energy_defense - current.energy_defense,
	}
