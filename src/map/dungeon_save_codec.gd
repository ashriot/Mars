class_name DungeonSaveCodec
extends RefCounted

const DUNGEON_PROFILE_SCRIPT = preload("res://src/scripts/enemies/dungeon_profile.gd")

const LOOT_BITS := 0
const LOOT_MATERIAL := 1
const LOOT_COMPONENT := 2
const LOOT_EQUIPMENT := 3
const LOOT_MOD := 4

const REQUIRED_MAP_KEYS := [
	"current_alert",
	"total_nodes",
	"nodes_done",
	"current_coords",
	"width",
	"height",
	"node_data",
	"terminal_memory",
	"encounter_memory",
	"reward_memory",
]

const REQUIRED_RUN_KEYS := ["seed", "tier", "profile_path", "map_data"]


static func is_valid_map_data(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in REQUIRED_MAP_KEYS:
		if not data.has(key):
			return false

	if not _is_number(data.current_alert):
		return false
	if not _is_number(data.total_nodes) or not _is_number(data.nodes_done):
		return false
	if not _is_number(data.width) or not _is_number(data.height):
		return false
	if data.width <= 0 or data.height <= 0:
		return false
	if not data.current_coords is String:
		return false
	if not data.node_data is Dictionary or data.node_data.is_empty():
		return false
	if not data.node_data.has(data.current_coords):
		return false

	for key in data.node_data:
		if not _is_serialized_coords(key):
			return false
		var node_data: Variant = data.node_data[key]
		if not node_data is Dictionary:
			return false
		for field in ["state", "visited", "aware", "type"]:
			if not node_data.has(field):
				return false
		if not _is_number(node_data.state) or not _is_number(node_data.type):
			return false
		if not node_data.visited is bool or not node_data.aware is bool:
			return false

	if not _is_valid_terminal_memory(data.terminal_memory):
		return false
	if not _is_valid_encounter_memory(data.encounter_memory):
		return false
	if not _is_valid_reward_memory(data.reward_memory):
		return false
	return true


static func is_valid_active_run(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key in REQUIRED_RUN_KEYS:
		if not data.has(key):
			return false
	if not _is_number(data.seed) or not _is_number(data.tier):
		return false
	if not data.profile_path is String or data.profile_path.is_empty():
		return false
	if not ResourceLoader.exists(data.profile_path):
		return false
	var profile = load(data.profile_path)
	if profile == null or not _resource_uses_script(profile, DUNGEON_PROFILE_SCRIPT):
		return false
	for optional_array in ["run_equipment", "run_mods"]:
		if data.has(optional_array) and not data[optional_array] is Array:
			return false
		if data.has(optional_array):
			for item in data[optional_array]:
				if not item is Dictionary:
					return false
	if data.has("run_inventory") and not data.run_inventory is Dictionary:
		return false
	return is_valid_map_data(data.map_data)


static func extract_node_types(data: Dictionary) -> Dictionary:
	var restored_types := {}
	for key in data.node_data:
		var coords: Vector2i = str_to_var(key)
		restored_types[coords] = int(data.node_data[key].type)
	return restored_types


static func _is_valid_terminal_memory(memory: Variant) -> bool:
	if not memory is Dictionary:
		return false
	for key in memory:
		if not _is_serialized_coords(key) or not memory[key] is Dictionary:
			return false
		var payload: Dictionary = memory[key]
		for field in ["facility_name", "session_id", "terminal_index", "bits", "alert", "upgrade_key"]:
			if not payload.has(field):
				return false
		if not payload.facility_name is String or not payload.session_id is String:
			return false
		if not payload.upgrade_key is String:
			return false
		if not _is_integer(payload.terminal_index) or not _is_integer(payload.bits):
			return false
		if not _is_number(payload.alert):
			return false
	return true


static func _is_valid_encounter_memory(memory: Variant) -> bool:
	if not memory is Dictionary:
		return false
	for key in memory:
		if not _is_serialized_coords(key) or not memory[key] is Array:
			return false
		var payload: Array = memory[key]
		if payload.size() != 3:
			return false
		if not payload[0] is String or not payload[1] is bool or not payload[2] is bool:
			return false
	return true


static func _is_valid_reward_memory(memory: Variant) -> bool:
	if not memory is Dictionary:
		return false
	for key in memory:
		if not _is_serialized_coords(key) or not memory[key] is Dictionary:
			return false
		var payload: Dictionary = memory[key]
		if not payload.has("type") or not _is_integer(payload.type):
			return false
		match int(payload.type):
			LOOT_BITS:
				if not _has_integer(payload, "amount"):
					return false
			LOOT_MATERIAL, LOOT_COMPONENT:
				if not _has_string(payload, "id") or not _has_integer(payload, "amount"):
					return false
			LOOT_EQUIPMENT:
				if not _has_string(payload, "id"):
					return false
			LOOT_MOD:
				if not _has_string(payload, "id") or not _has_integer(payload, "tier"):
					return false
			_:
				return false
	return true


static func _has_string(data: Dictionary, key: String) -> bool:
	return data.has(key) and data[key] is String


static func _has_integer(data: Dictionary, key: String) -> bool:
	return data.has(key) and _is_integer(data[key])


static func _resource_uses_script(resource: Resource, expected_script: Script) -> bool:
	var script: Script = resource.get_script()
	while script != null:
		if script == expected_script:
			return true
		script = script.get_base_script()
	return false


static func _is_serialized_coords(value: Variant) -> bool:
	if not value is String:
		return false
	return str_to_var(value) is Vector2i


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
