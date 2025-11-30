extends Resource
class_name EquipmentMod

@export var mod_name: String = ""
@export_range(3, 5) var min_tier_required: int = 3

@export var stat_to_reduce: ActorStats.Stats
@export var stat_to_increase: ActorStats.Stats

func get_stat_changes(item_tier: int) -> Dictionary:
	if item_tier < 3: return {}

	var penalty = -2
	var bonus = 0

	match item_tier:
		3: bonus = 2
		4: bonus = 3
		5: bonus = 4
		_: bonus = 4

	return {
		stat_to_reduce: penalty,
		stat_to_increase: bonus
	}
