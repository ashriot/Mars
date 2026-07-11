class_name DungeonSaveCodec
extends RefCounted

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

	if not _is_valid_memory(data.terminal_memory, TYPE_DICTIONARY):
		return false
	if not _is_valid_memory(data.encounter_memory, TYPE_ARRAY):
		return false
	if not _is_valid_memory(data.reward_memory, TYPE_DICTIONARY):
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
	for optional_array in ["run_equipment", "run_mods"]:
		if data.has(optional_array) and not data[optional_array] is Array:
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


static func _is_valid_memory(memory: Variant, value_type: int) -> bool:
	if not memory is Dictionary:
		return false
	for key in memory:
		if not _is_serialized_coords(key) or typeof(memory[key]) != value_type:
			return false
	return true


static func _is_serialized_coords(value: Variant) -> bool:
	if not value is String:
		return false
	return str_to_var(value) is Vector2i


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
