extends Resource
class_name DungeonProfile

@export var profile_name: String = ""

@export_group("Encounter Pools")
@export var normal_encounters: Array[Encounter]
@export var elite_encounters: Array[Encounter]
@export var boss_encounter: Encounter

@export_group("Node Multipliers")
@export var terminal_mult: float = 1.0
@export var combat_mult: float = 1.0
@export var elite_mult: float = 1.0
@export var reward_common_mult: float = 1.0
@export var reward_uncommon_mult: float = 1.0
@export var reward_rare_mult: float = 1.0
@export var reward_epic_mult: float = 1.0
@export var event_mult: float = 1.0

# Helper to pick a valid fight for the current tier
func pick_encounter(tier: int, is_elite: bool) -> Encounter:
	var pool = elite_encounters if is_elite else normal_encounters
	var valid = []

	for enc in pool:
		if tier >= enc.min_tier and tier <= enc.max_tier:
			valid.append(enc)

	if valid.is_empty():
		push_warning("No valid encounter found for Tier %d in profile %s" % [tier, profile_name])
		return pool.pick_random() if not pool.is_empty() else null

	return valid.pick_random()

func get_node_multiplier(node_type: String) -> float:
	match node_type:
		"terminal": return terminal_mult
		"combat": return combat_mult
		"elite": return elite_mult
		"reward_common": return reward_common_mult
		"reward_uncommon": return reward_uncommon_mult
		"reward_rare": return reward_rare_mult
		"reward_epic": return reward_epic_mult
		"event": return event_mult
	return 1.0
