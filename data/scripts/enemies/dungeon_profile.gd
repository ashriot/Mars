extends Resource
class_name DungeonProfile

@export var profile_name: String = "Mars Surface"

@export_group("Encounter Pools")
@export var normal_encounters: Array[Encounter]
@export var elite_encounters: Array[Encounter]
@export var boss_encounter: Encounter

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
