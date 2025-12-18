extends Resource
class_name EquipmentMod

# --- IDENTITY ---
@export var id: String = ""
@export var mod_name: String = ""
@export var icon: Texture2D

@export_range(1, 5) var tier: int = 1

# --- STAR RATINGS ---
@export_group("Star Ratings")
@export var hp: int = 0
@export var guard: int = 0
@export var focus: int = 0
@export var atk: int = 0
@export var psy: int = 0
@export var ovr: int = 0
@export var spd: int = 0
@export var aim: int = 0
@export var pre: int = 0
@export var kin_def: int = 0
@export var nrg_def: int = 0


func get_stat_changes() -> Dictionary:
	var changes = {}
	var tier_mult = _get_multiplier()

	var _add = func(stat_enum, rating, stat_mult = 1.0):
		if rating != 0:
			var val = int((rating * 0.15 + 0.25) * tier_mult * stat_mult)
			changes[stat_enum] = val

	_add.call(ActorStats.Stats.HP, hp, 10.0)
	_add.call(ActorStats.Stats.GRD, guard)
	_add.call(ActorStats.Stats.FOC, focus)
	_add.call(ActorStats.Stats.ATK, atk)
	_add.call(ActorStats.Stats.PSY, psy)
	_add.call(ActorStats.Stats.OVR, ovr, 2.0)
	_add.call(ActorStats.Stats.SPD, spd, 0.5)
	_add.call(ActorStats.Stats.AIM, aim)
	_add.call(ActorStats.Stats.PRE, pre)
	_add.call(ActorStats.Stats.KIN_DEF, kin_def)
	_add.call(ActorStats.Stats.NRG_DEF, nrg_def)

	return changes

func _get_multiplier() -> int:
	var bonus = ((pow(tier, 2) * 0.65) + 4.5) * 5
	return int(bonus)

func get_save_data() -> Dictionary:
	return {
		"id": id,
		"tier": tier
	}

static func create_from_save_data(data: Dictionary) -> EquipmentMod:
	var load_id = data.get("id", "")
	var instance = ItemDatabase.get_item_resource(load_id)
	instance.tier = int(data.get("tier", 1))
	return instance
