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
		"terminal_memory": {terminal_key: {
			"facility_name": "ALPHA NODE 1",
			"session_id": "fixed-session",
			"terminal_index": 0,
			"bits": 12,
			"alert": 5.0,
			"upgrade_key": "power",
		}},
		"encounter_memory": {entrance_key: ["encounter_1", false, false]},
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


func test_container_correct_but_malformed_payload_memories_are_rejected() -> void:
	var codec = _codec()
	var malformed_terminal := _valid_map_data()
	var terminal_key = malformed_terminal.terminal_memory.keys()[0]
	malformed_terminal.terminal_memory[terminal_key].erase("upgrade_key")
	assert_false(codec.is_valid_map_data(malformed_terminal))

	var malformed_encounter := _valid_map_data()
	var encounter_key = malformed_encounter.encounter_memory.keys()[0]
	malformed_encounter.encounter_memory[encounter_key] = ["encounter_1", false]
	assert_false(codec.is_valid_map_data(malformed_encounter))

	var malformed_reward := _valid_map_data()
	var reward_key = malformed_reward.reward_memory.keys()[0]
	malformed_reward.reward_memory[reward_key] = {"type": 0}
	assert_false(codec.is_valid_map_data(malformed_reward))


func test_active_run_rejects_existing_non_dungeon_profile_resource() -> void:
	var codec = _codec()
	assert_false(codec.is_valid_active_run({
		"seed": 42,
		"tier": 1,
		"profile_path": "res://icon.svg",
		"map_data": _valid_map_data(),
	}))
