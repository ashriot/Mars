extends Resource
class_name Equipment

enum Slot { WEAPON, ARMOR, ACCESSORY }
enum Rarity { COMMON, UNIQUE }

# --- IDENTITY ---
@export var equipment_id: String = ""
@export var item_name: String = ""
@export var slot: Slot = Slot.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture

# --- PROGRESSION STATE ---
@export_range(1, 5) var tier: int = 1
@export_range(1, 20) var rank: int = 1
@export var current_xp: int = 0

# --- STAR RATINGS ---
@export_group("Star Ratings")
@export_range(0, 10) var star_hp: int = 0
@export_range(0, 10) var star_guard: int = 0
@export_range(0, 10) var star_focus: int = 0
@export_range(0, 10) var star_atk: int = 0
@export_range(0, 10) var star_psy: int = 0
@export_range(0, 10) var star_ovr: int = 0
@export_range(0, 10) var star_spd: int = 0
@export_range(0, 10) var star_aim: int = 0
@export_range(0, 10) var star_kin_def: int = 0
@export_range(0, 10) var star_nrg_def: int = 0

# --- SOCKETS & TRAITS ---
@export_group("Sockets")
@export var equipped_mod: EquipmentMod

@export_group("Unique Traits")
@export var unique_trait: Trait

# --- CONSTANTS ---
const XP_PER_RANK_BASE = 100

# ===================================================================
# STAT CALCULATION
# ===================================================================

func calculate_stats() -> ActorStats:
	var stats = ActorStats.new()

	# 1. Get Base Ratings (Stars)
	var ratings = _get_base_ratings_dict()

	# 2. Apply Mod
	if equipped_mod:
		var changes = equipped_mod.get_stat_changes(tier)
		for stat_enum in changes:
			if ratings.has(stat_enum):
				ratings[stat_enum] = max(0, ratings[stat_enum] + changes[stat_enum])

	if slot == Slot.ARMOR:
		if ratings.has(ActorStats.Stats.HP):
			stats.max_hp = _calc_stat(ratings[ActorStats.Stats.HP]) * 5
		if ratings.has(ActorStats.Stats.GRD):
			stats.starting_guard = ratings[ActorStats.Stats.GRD]
		if ratings.has(ActorStats.Stats.FOC):
			stats.starting_focus = ratings[ActorStats.Stats.FOC]
		if ratings.has(ActorStats.Stats.KIN_DEF):
			stats.kinetic_defense = (ratings[ActorStats.Stats.KIN_DEF] * 5) + 10
		if ratings.has(ActorStats.Stats.NRG_DEF):
			stats.energy_defense = (ratings[ActorStats.Stats.NRG_DEF] * 5) + 10

	elif slot == Slot.WEAPON:
		if ratings.has(ActorStats.Stats.ATK):
			stats.attack = _calc_stat(ratings[ActorStats.Stats.ATK])
		if ratings.has(ActorStats.Stats.PSY):
			stats.psyche = _calc_stat(ratings[ActorStats.Stats.PSY])
		if ratings.has(ActorStats.Stats.OVR):
			stats.overload = _calc_stat(ratings[ActorStats.Stats.OVR], 0) * 3
		if ratings.has(ActorStats.Stats.AIM):
			stats.aim = (ratings[ActorStats.Stats.KIN_DEF] * 5) + 10
			stats.aim_dmg = _calc_stat(ratings[ActorStats.Stats.AIM])

	if ratings.has(ActorStats.Stats.SPD):
		stats.speed = _calc_stat(ratings[ActorStats.Stats.SPD]) / 2

	return stats

func _get_multiplier() -> float:
	return pow((rank + 5), 2) * 0.048

func _calc_stat(rating: int, base: int = 5) -> int:
	return int(((rating + base) * _get_multiplier()))

func _get_base_ratings_dict() -> Dictionary:
	return {
		ActorStats.Stats.HP: star_hp,
		ActorStats.Stats.GRD: star_guard,
		ActorStats.Stats.FOC: star_focus,
		ActorStats.Stats.ATK: star_atk,
		ActorStats.Stats.PSY: star_psy,
		ActorStats.Stats.OVR: star_ovr,
		ActorStats.Stats.SPD: star_spd,
		ActorStats.Stats.AIM: star_aim,
		ActorStats.Stats.KIN_DEF: star_kin_def,
		ActorStats.Stats.NRG_DEF: star_nrg_def
	}

# ===================================================================
# UPGRADE LOGIC
# ===================================================================

func get_stat_preview_at_rank(target_rank: int) -> ActorStats:
	var current_rank = rank
	rank = target_rank
	var preview = calculate_stats()
	rank = current_rank
	return preview

func get_stat_gain_on_upgrade() -> Dictionary:
	var current = calculate_stats()
	var next = get_stat_preview_at_rank(rank + 1)

	return {
		"hp": next.max_hp - current.max_hp,
		"guard": next.starting_guard - current.starting_guard,
		"focus": next.starting_focus - current.starting_focus,
		"attack": next.attack - current.attack,
		"psyche": next.psyche - current.psyche,
		"overload": next.overload - current.overload,
		"speed": next.speed - current.speed,
		"aim": next.aim - current.aim,
		"kinetic_defense": next.kinetic_defense - current.kinetic_defense,
		"energy_defense": next.energy_defense - current.energy_defense,
	}

func get_xp_to_next_rank() -> int:
	if rank >= 20: return 0
	# Cost: Target Rank * 100
	# e.g. Rank 1 -> 2 costs 200 XP.
	return (rank + 1) * XP_PER_RANK_BASE

func get_rank_cap() -> int:
	return tier * 4 # T1=4, T2=8, T3=12, T4=16, T5=20

func can_add_xp() -> bool:
	return rank < get_rank_cap()

func add_xp(amount: int):
	if not can_add_xp():
		return # Capped by Tier

	current_xp += amount

	# Handle Level Up(s)
	while true:
		var needed = get_xp_to_next_rank()
		if needed > 0 and current_xp >= needed:
			current_xp -= needed
			rank += 1
			print("Equipment Rank Up! Now Rank ", rank)

			# Stop if we hit the tier cap
			if rank >= get_rank_cap():
				current_xp = 0 # Discard overflow or keep it? Usually discard or cap.
				break
		else:
			break

# Call this when crafting components are spent
func upgrade_tier():
	if tier < 5:
		tier += 1
		print("Equipment Tier Up! Now Tier ", tier, ". Rank Cap is ", get_rank_cap())

# ===================================================================
# SAVE / LOAD
# ===================================================================

func get_save_data() -> Dictionary:
	return {
		"id": equipment_id,
		"tier": tier,
		"rank": rank,
		"xp": current_xp,
		"mod_id": equipped_mod.resource_path if equipped_mod else "" # Or use an ID system for mods
	}

static func create_from_save_data(data: Dictionary) -> Equipment:
	var id = data.get("id", "")
	var instance = ItemDatabase.get_item_resource(id)

	if instance:
		instance.tier = data.get("tier", 1)
		instance.rank = data.get("rank", 1)
		instance.current_xp = data.get("xp", 0)

		var mod_path = data.get("mod_id", "")
		if mod_path != "":
			instance.equipped_mod = load(mod_path)

		return instance
	return null
