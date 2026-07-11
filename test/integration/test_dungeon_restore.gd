extends GutTest

const DUNGEON_MAP_SCENE := preload("res://src/map/dungeon_map.tscn")


func _make_map() -> DungeonMap:
	var dungeon_map := DUNGEON_MAP_SCENE.instantiate() as DungeonMap
	add_child_autofree(dungeon_map)
	dungeon_map.map_length = 2
	dungeon_map.map_height = 1
	await get_tree().process_frame
	return dungeon_map


func test_restore_preserves_authoritative_map_state_and_danger_vision() -> void:
	var source := await _make_map()
	await source.generate_hex_grid(false, {
		Vector2i(0, 0): MapNode.NodeType.ENTRANCE,
		Vector2i(1, 0): MapNode.NodeType.EXIT,
	})
	var coords: Array = source.grid_nodes.keys()
	coords.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.y < b.y)
	var current_coords: Vector2i = coords[1]
	source.current_node = source.grid_nodes[current_coords]
	source.total_nodes = 2
	source.nodes_done = 1
	source.current_alert = 80.0

	var saved := source.get_save_data()
	var current_key := var_to_str(current_coords)
	var other_key := var_to_str(coords[0])
	saved.node_data[current_key].type = MapNode.NodeType.TERMINAL
	saved.node_data[current_key].state = MapNode.NodeState.REVEALED
	saved.node_data[current_key].visited = true
	saved.node_data[current_key].aware = true
	saved.terminal_memory[current_key] = {
		"facility_name": "ALPHA NODE 1",
		"session_id": "restore-session",
		"terminal_index": 0,
		"bits": 37,
		"alert": 5.0,
		"upgrade_key": "power",
	}
	saved.encounter_memory[other_key] = ["encounter_restore", true, false]
	saved.reward_memory[other_key] = {"type": 0, "amount": 23}

	var restored := await _make_map()
	var did_restore: bool = await restored.load_from_save_data(saved)

	assert_true(did_restore)
	assert_eq(restored.current_alert, 80.0)
	assert_eq(restored.current_node.grid_coords, current_coords)
	assert_eq(restored.current_node.type, MapNode.NodeType.TERMINAL)
	assert_eq(restored.terminal_memory[current_coords], saved.terminal_memory[current_key])
	assert_eq(restored.vision_range, 0)
	assert_eq(restored.node_gauge.max_value, 2.0)

	var resaved := restored.get_save_data()
	assert_eq(resaved.current_coords, saved.current_coords)
	assert_eq(resaved.current_alert, saved.current_alert)
	assert_eq(resaved.total_nodes, saved.total_nodes)
	assert_eq(resaved.nodes_done, saved.nodes_done)
	assert_eq(resaved.node_data, saved.node_data)
	assert_eq(resaved.terminal_memory, saved.terminal_memory)
	assert_eq(resaved.encounter_memory, saved.encounter_memory)
	assert_eq(resaved.reward_memory, saved.reward_memory)
