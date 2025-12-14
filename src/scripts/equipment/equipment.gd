extends Resource
class_name Equipment

enum Slot { WEAPON, ARMOR }
enum EquipmentType { PISTOL, SHOTGUN, RIFLE, CLOTHES, SUIT, VEST }

# --- IDENTITY ---
@export var id: String = ""
@export var item_name: String = ""
@export var slot: Slot = Slot.WEAPON
@export var type: EquipmentType = EquipmentType.PISTOL
@export var icon: Texture

# --- PROGRESSION STATE ---
@export_range(0, 5) var tier: int = 0
@export_range(1, 30) var rank: int = 1
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
@export_range(0, 10) var star_pre: int = 0
@export_range(0, 10) var star_kin_def: int = 0
@export_range(0, 10) var star_nrg_def: int = 0

# --- SOCKETS & TRAITS ---
@export_group("Customization")
@export var group: TraitDatabase.Group = TraitDatabase.Group.NONE
@export var unique_trait: Trait
@export var invested_shared_trait: int = 0 # Max 3
@export var invested_unique_trait: int = 0 # Max 3
@export var invested_stat_boosts: Dictionary = {}
@export var installed_mods: Array[EquipmentMod] = []

const XP_PER_RANK_BASE = 100


func get_display_name() -> String:
	if tier > 0:
		return "%s+%d" % [item_name, tier]
	return item_name

func get_max_mod_slots() -> int:
	return tier

func get_available_proficiency_points() -> int:
	var spent = invested_shared_trait + invested_unique_trait + invested_stat_boosts.values().reduce(func(a, b): return a + b, 0)
	return tier - spent

func calculate_stats() -> ActorStats:
	var stats = ActorStats.new()
	var ratings = _get_base_ratings_dict()

	# 1. Apply "Stat Boost" Proficiency Points (The +1 Rating)
	for stat_key in invested_stat_boosts:
		var boost_amount = invested_stat_boosts[stat_key]
		if ratings.has(stat_key):
			ratings[stat_key] += boost_amount

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
			stats.precision = _calc_stat(ratings[ActorStats.Stats.PRE])

	if ratings.has(ActorStats.Stats.SPD):
		stats.speed = _calc_stat(ratings[ActorStats.Stats.SPD]) / 2

	var allowed_slots = get_max_mod_slots()

	for i in range(installed_mods.size()):
		if i >= allowed_slots: break

		var mod = installed_mods[i]
		if not mod: continue

		# Get the raw values (e.g. +20, -10)
		var changes = mod.get_stat_changes(tier)

		for stat_enum in changes:
			var bonus = changes[stat_enum]
			stats.add_stat(stat_enum, bonus) # Assuming ActorStats has add_stat helper

	return stats

func _get_multiplier() -> float:
	return (rank + pow(rank, 2) * 0.03) / 2 + 1.5

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
		ActorStats.Stats.PRE: star_pre,
		ActorStats.Stats.KIN_DEF: star_kin_def,
		ActorStats.Stats.NRG_DEF: star_nrg_def
	}

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
	if rank >= 30: return 0
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

func upgrade_tier():
	if tier < 5:
		tier += 1
		print("Equipment Tier Up! Now Tier ", tier, ". Rank Cap is ", get_rank_cap())

func get_save_data() -> Dictionary:
	var saved_mods = []
	for mod in installed_mods:
		saved_mods.append(mod.id if mod else "")

	return {
		"id": id,
		"tier": tier,
		"rank": rank,
		"xp": current_xp,

		# Proficiency State
		"inv_shared": invested_shared_trait,
		"inv_unique": invested_unique_trait,
		"inv_stats": invested_stat_boosts, # Saves as {"2": 1, "5": 1}

		"mods": saved_mods
	}

static func create_from_save_data(data: Dictionary) -> Equipment:
	var load_id = data.get("id", "")
	var instance = ItemDatabase.get_item_resource(load_id) # Loads base Pistol.tres

	if instance:
		instance.tier = int(data.get("tier", 0))
		instance.rank = int(data.get("rank", 1))
		instance.current_xp = int(data.get("xp", 0))

		instance.invested_shared_trait = int(data.get("inv_shared", 0))
		instance.invested_unique_trait = int(data.get("inv_unique", 0))

		# --- FIX: RESTORE DICTIONARY KEYS TO INT ---
		# JSON forces keys to Strings. We must cast them back to Ints
		# so calculate_stats() can match them against the Enums.
		var raw_stats = data.get("inv_stats", {})
		instance.invested_stat_boosts.clear()

		for key_str in raw_stats.keys():
			var stat_enum = int(key_str) # "2" -> 2
			var value = int(raw_stats[key_str])
			instance.invested_stat_boosts[stat_enum] = value
		# -------------------------------------------

		# Load Mods
		var saved_mods = data.get("mods", [])
		instance.installed_mods.clear()
		for mod_id in saved_mods:
			if mod_id != "":
				var mod_res = ItemDatabase.get_item_resource(mod_id)
				# Verify it's actually a mod before appending
				if mod_res is EquipmentMod:
					instance.installed_mods.append(mod_res)
				else:
					instance.installed_mods.append(null) # Fallback
			else:
				instance.installed_mods.append(null) # Empty slot

		return instance
	return null
