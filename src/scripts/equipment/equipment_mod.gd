extends Resource
class_name EquipmentMod

@export var id: String = ""
@export var mod_name: String = ""
@export_range(0, 5) var min_tier_required: int = 1

# Dictionary mapping ActorStats.Stats (int) -> float (scaling per tier)
# Example in Inspector:
# Key: 2 (ATK) -> Value: 4.0
# Key: 4 (OVR) -> Value: -4.0
@export var stat_bonuses_per_tier: Dictionary = {}

func get_stat_changes(item_tier: int) -> Dictionary:
	if item_tier < min_tier_required:
		return {}

	var changes = {}

	for stat_enum in stat_bonuses_per_tier.keys():
		var scaling_factor = stat_bonuses_per_tier[stat_enum]

		# Calculate raw bonus: Factor * Tier
		# e.g. 4.0 * 5 = 20
		var final_val = int(scaling_factor * item_tier)

		changes[stat_enum] = final_val

	return changes
