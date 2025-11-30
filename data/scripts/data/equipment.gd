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

	stats.speed = _calc_stat(speed_rank) / 2 if speed_rank > 0 else 0

	if slot == Slot.WEAPON:
		stats.attack = _calc_stat(attack_rank) if attack_rank > 0 else 0
		stats.psyche = _calc_stat(psyche_rank) if psyche_rank > 0 else 0
		stats.overload = _calc_stat(overload_rank, 0) * 3 if overload_rank > 0 else 0
		stats.aim_bonus = _calc_stat(aim_rank) if aim_rank > 0 else 0

		stats.aim = int(level / 2.0) + ((aim_rank * 4) if aim_rank > 0 else 0)
		stats.aim = clampi(stats.aim, 0, 75)
	elif slot == Slot.ARMOR:
		stats.starting_guard = guard_rank
		stats.max_hp = _calc_stat(hp_rank) * 5 if hp_rank > 0 else 0
		stats.starting_guard = int(level / 10) + guard_rank + 2 if guard_rank > 0 else 0
		stats.overload = 0
		stats.aim = 0
		stats.kinetic_defense = int(level / 2.0) + (kinetic_defense_rank * 15) - 10
		stats.energy_defense = int(level / 2.0) + (energy_defense_rank * 15) - 10
		stats.kinetic_defense = clampi(stats.kinetic_defense, 0, 90)
		stats.energy_defense = clampi(stats.energy_defense, 0, 90)

	return stats

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

func get_save_data() -> Dictionary:
	return {
		"id": equipment_id,
		"lvl": level,
		# If you implement random affixes later, save them here too
		# "affixes": [...]
	}

func _get_multiplier(base: int = 5) -> float:
	return pow((level + base), 2) * 0.048

func _calc_stat(rank: int, rank_bonus: int = 5) -> int:
	return int(((rank + rank_bonus) * _get_multiplier()))

static func create_from_save_data(data: Dictionary) -> Equipment:
	var id = data.get("id", "")
	var lvl = data.get("lvl", 1)

	# 1. Ask the Database for the base item
	var instance = ItemDatabase.get_item_resource(id)

	if instance:
		# 2. Apply the saved state
		instance.level = lvl
		return instance

	return null
