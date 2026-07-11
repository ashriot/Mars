extends GutTest

const PROFILE_PATH := "res://data/enemies/dungeon_profiles/first_alleyway.tres"
const CODEC_PATH := "res://src/map/dungeon_save_codec.gd"


func _valid_map_data() -> Dictionary:
	var entrance_key := var_to_str(Vector2i(0, 0))
	var terminal_key := var_to_str(Vector2i(1, 0))
	return {
		"current_alert": 80.0,
		"total_nodes": 2,
		"nodes_done": 1,
		"current_coords": terminal_key,
		"width": 2,
		"height": 1,
		"node_data": {
			entrance_key: {"state": 2, "visited": true, "aware": true, "type": MapNode.NodeType.ENTRANCE},
			terminal_key: {"state": 1, "visited": true, "aware": true, "type": MapNode.NodeType.TERMINAL},
		},
		"terminal_memory": {terminal_key: {"session_id": "fixed-session", "bits": 12}},
		"encounter_memory": {},
		"reward_memory": {entrance_key: {"type": 0, "amount": 12}},
	}


func _codec():
	var script = load(CODEC_PATH)
	assert_not_null(script, "DungeonSaveCodec must exist")
	return script


func test_extract_node_types_converts_serialized_coordinates() -> void:
	var codec = _codec()
	if codec == null:
		return
	var types: Dictionary = codec.extract_node_types(_valid_map_data())

	assert_eq(types[Vector2i(0, 0)], MapNode.NodeType.ENTRANCE)
	assert_eq(types[Vector2i(1, 0)], MapNode.NodeType.TERMINAL)


func test_missing_node_data_is_rejected() -> void:
	var codec = _codec()
	if codec == null:
		return
	var data := _valid_map_data()
	data.erase("node_data")

	assert_false(codec.is_valid_map_data(data))


func test_current_coordinate_outside_saved_nodes_is_rejected() -> void:
	var codec = _codec()
	if codec == null:
		return
	var data := _valid_map_data()
	data.current_coords = var_to_str(Vector2i(9, 9))

	assert_false(codec.is_valid_map_data(data))


func test_malformed_active_run_is_rejected() -> void:
	var codec = _codec()
	if codec == null:
		return
	assert_false(codec.is_valid_active_run({"profile_path": PROFILE_PATH}))
	assert_false(codec.is_valid_active_run({
		"seed": 42,
		"tier": 1,
		"profile_path": PROFILE_PATH,
		"map_data": {"unsafe": true},
	}))


func test_valid_active_run_accepts_existing_profile_without_optional_rewards() -> void:
	var codec = _codec()
	if codec == null:
		return
	assert_true(codec.is_valid_active_run({
		"seed": 42,
		"tier": 1,
		"profile_path": PROFILE_PATH,
		"map_data": _valid_map_data(),
	}))
