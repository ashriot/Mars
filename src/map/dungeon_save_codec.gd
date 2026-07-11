class_name DungeonSaveCodec
extends RefCounted

const DUNGEON_PROFILE_SCRIPT = preload("res://src/scripts/enemies/dungeon_profile.gd")
const EQUIPMENT_SCRIPT = preload("res://src/scripts/equipment/equipment.gd")
const EQUIPMENT_MOD_SCRIPT = preload("res://src/scripts/equipment/equipment_mod.gd")
const MAP_NODE_SCRIPT = preload("res://src/map/map_node.gd")

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
	if not _is_integer(data.width) or not _is_integer(data.height):
		return false
	if data.width <= 0 or data.height <= 0:
		return false
	if not data.current_coords is String:
		return false
	if not data.node_data is Dictionary or data.node_data.is_empty():
		return false
	var expected_coords := _expected_coordinate_keys(int(data.width), int(data.height))
	if data.node_data.size() != expected_coords.size():
		return false
	for expected_key in expected_coords:
		if not data.node_data.has(expected_key):
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
		if not _is_integer(node_data.state) or not _is_integer(node_data.type):
			return false
		if int(node_data.state) < 0 or int(node_data.state) >= MAP_NODE_SCRIPT.NodeState.size():
			return false
		if int(node_data.type) < 0 or int(node_data.type) >= MAP_NODE_SCRIPT.NodeType.size():
			return false
		if not node_data.visited is bool or not node_data.aware is bool:
			return false

	if not _is_valid_terminal_memory(data.terminal_memory):
		return false
	if not _is_valid_encounter_memory(data.encounter_memory):
		return false
	if not _is_valid_reward_memory(data.reward_memory):
		return false
	for memory in [data.terminal_memory, data.encounter_memory, data.reward_memory]:
		for memory_key in memory:
			if not data.node_data.has(memory_key):
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
	if data.has("run_equipment") and not _is_valid_saved_items(data.run_equipment, false):
		return false
	if data.has("run_mods") and not _is_valid_saved_items(data.run_mods, true):
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


static func _expected_coordinate_keys(width: int, height: int) -> Dictionary:
	var keys := {}
	var center_y: float = floor(height / 2.0)
	var visual_center_x: float = (width - 1) / 2.0 + (0.5 if int(center_y) % 2 == 0 else 0.0)
	for y in range(height):
		var x_count := width - int(abs(y - center_y))
		if x_count <= 0:
			continue
		var current_shift := 0.5 if y % 2 == 0 else 0.0
		var x_start: int = roundi(visual_center_x - current_shift - ((x_count - 1) / 2.0))
		for i in range(x_count):
			keys[var_to_str(Vector2i(x_start + i, y))] = true
	return keys


static func _is_valid_saved_items(items: Variant, expect_mod: bool) -> bool:
	if not items is Array:
		return false
	for saved_item in items:
		if not saved_item is Dictionary:
			return false
		if not _has_string(saved_item, "id") or saved_item.id.is_empty():
			return false
		var resource := _find_item_resource(saved_item.id)
		var expected_script := EQUIPMENT_MOD_SCRIPT if expect_mod else EQUIPMENT_SCRIPT
		if resource == null or not _resource_uses_script(resource, expected_script):
			return false
		if expect_mod:
			if saved_item.has("tier") and not _is_integer(saved_item.tier):
				return false
		else:
			if not _is_valid_equipment_fields(saved_item):
				return false
	return true


static func _is_valid_equipment_fields(data: Dictionary) -> bool:
	for field in ["tier", "rank", "xp", "inv_shared", "inv_unique"]:
		if data.has(field) and not _is_integer(data[field]):
			return false
	if data.has("inv_stats"):
		if not data.inv_stats is Dictionary:
			return false
		for stat_key in data.inv_stats:
			if not stat_key is String and not _is_integer(stat_key):
				return false
			if not _is_integer(data.inv_stats[stat_key]):
				return false
	if data.has("mods"):
		if not data.mods is Array:
			return false
		for mod_id in data.mods:
			if not mod_id is String:
				return false
			if not mod_id.is_empty():
				var mod_resource := _find_item_resource(mod_id)
				if mod_resource == null or not _resource_uses_script(mod_resource, EQUIPMENT_MOD_SCRIPT):
					return false
	return true


static func _find_item_resource(id: String) -> Resource:
	return ItemDatabase.get_item_resource(id)


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
		if payload.has("color_html"):
			if not payload.color_html is String or not Color.html_is_valid(payload.color_html):
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
