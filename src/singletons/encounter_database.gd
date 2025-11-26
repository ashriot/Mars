# EncounterDatabase.gd (Autoload)
extends Node

# We categorize them for fast lookup
var normal_encounters: Array[Encounter] = []
var elite_encounters: Array[Encounter] = []
var boss_encounters: Array[Encounter] = []

var _id_map: Dictionary = {}

func _ready():
	# Scan your data folder for .tres files
	_scan_for_encounters("res://data/enemies/encounters/")

func _scan_for_encounters(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_scan_for_encounters(path + "/" + file_name)
			elif file_name.ends_with(".tres") or file_name.ends_with(".remap"):
				var clean_name = file_name.replace(".remap", "")
				var res = load(path + "/" + clean_name)

				if res is Encounter:
					if res.encounter_id != "":
						_id_map[res.encounter_id] = res
					else:
						push_error("Encounter missing ID: " + file_name)

			file_name = dir.get_next()
	else:
		push_error("EncounterDatabase: Could not open path: " + path)

func _register_encounter(enc: Encounter):
	if enc.is_boss:
		boss_encounters.append(enc)
	elif enc.is_elite:
		elite_encounters.append(enc)
	else:
		normal_encounters.append(enc)

func get_encounter_by_id(id: String) -> Encounter:
	return _id_map.get(id)

func get_random_encounter(tier: int, type: MapNode.NodeType) -> Encounter:
	var source_array: Array[Encounter] = []

	match type:
		MapNode.NodeType.COMBAT: source_array = normal_encounters
		MapNode.NodeType.ELITE: source_array = elite_encounters
		MapNode.NodeType.BOSS: source_array = boss_encounters
		_: return null

	# Filter by Tier
	var valid_pool: Array[Encounter] = []
	for enc in source_array:
		if tier >= enc.min_tier and tier <= enc.max_tier:
			valid_pool.append(enc)

	if valid_pool.is_empty():
		push_warning("No encounters found for Tier " + str(tier) + " Type " + str(type))
		# Fallback: return anything from source to prevent crash
		return source_array.pick_random() if not source_array.is_empty() else null

	return valid_pool.pick_random()
