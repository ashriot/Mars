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


func test_reward_payload_rejects_non_string_optional_color_html() -> void:
	var codec = _codec()
	var data := _valid_map_data()
	var reward_key = data.reward_memory.keys()[0]
	data.reward_memory[reward_key].color_html = 42

	assert_false(codec.is_valid_map_data(data))


func test_public_runtime_payload_validators_accept_each_valid_category() -> void:
	var codec = _codec()
	assert_true(codec.is_valid_terminal_payload({
		"facility_name": "ALPHA",
		"session_id": "session",
		"terminal_index": 0,
		"bits": 12,
		"alert": 5.0,
		"upgrade_key": "scan",
	}))
	assert_true(codec.is_valid_encounter_payload(["attack_drones_1", false, false]))
	for payload in [
		{"type": 0, "amount": 12},
		{"type": 1, "id": "material", "amount": 2},
		{"type": 2, "id": "component", "amount": 2, "color_html": "#ff00ff"},
		{"type": 3, "id": "equipment"},
		{"type": 4, "id": "mod", "tier": 2},
	]:
		assert_true(codec.is_valid_reward_payload(payload))


func test_map_geometry_requires_integer_dimensions_and_exact_coordinate_set() -> void:
	var codec = _codec()
	var fractional := _valid_map_data()
	fractional.width = 2.5
	assert_false(codec.is_valid_map_data(fractional))

	var missing := _valid_map_data()
	missing.node_data.erase(var_to_str(Vector2i(0, 0)))
	assert_false(codec.is_valid_map_data(missing))

	var extra := _valid_map_data()
	extra.node_data[var_to_str(Vector2i(9, 9))] = extra.node_data.values()[0].duplicate()
	assert_false(codec.is_valid_map_data(extra))


func test_map_nodes_reject_values_outside_state_and_type_enums() -> void:
	var codec = _codec()
	var invalid_type := _valid_map_data()
	invalid_type.node_data.values()[0].type = 99
	assert_false(codec.is_valid_map_data(invalid_type))

	var invalid_state := _valid_map_data()
	invalid_state.node_data.values()[0].state = 99
	assert_false(codec.is_valid_map_data(invalid_state))


func test_active_run_validates_equipment_and_mod_resource_types() -> void:
	var codec = _codec()
	var valid_run := {
		"seed": 42,
		"tier": 1,
		"profile_path": PROFILE_PATH,
		"map_data": _valid_map_data(),
		"run_equipment": [{
			"id": "pistol", "tier": 1, "rank": 2, "xp": 3,
			"inv_shared": 0, "inv_unique": 0, "inv_stats": {},
			"mods": ["health_booster"],
		}],
		"run_mods": [{"id": "health_booster", "tier": 2}],
	}
	assert_true(codec.is_valid_active_run(valid_run))
	var empty_mod_slot := valid_run.duplicate(true)
	empty_mod_slot.run_equipment[0].mods = [""]
	assert_true(codec.is_valid_active_run(empty_mod_slot))

	for bad_equipment in [
		{},
		{"id": "missing_item"},
		{"id": "health_booster"},
		{"id": "pistol", "inv_stats": []},
		{"id": "pistol", "mods": [42]},
		{"id": "pistol", "mods": ["missing_mod"]},
		{"id": "pistol", "mods": ["pistol"]},
		{"id": "pistol", "tier": "one"},
	]:
		var run := valid_run.duplicate(true)
		run.run_equipment = [bad_equipment]
		assert_false(codec.is_valid_active_run(run))

	for bad_mod in [
		{},
		{"id": "missing_item"},
		{"id": "pistol"},
		{"id": "health_booster", "tier": "two"},
	]:
		var run := valid_run.duplicate(true)
		run.run_mods = [bad_mod]
		assert_false(codec.is_valid_active_run(run))
