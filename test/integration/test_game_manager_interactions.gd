extends GutTest


class InteractionManagerDouble extends GameManager:
	var completed_count := 0
	var canceled_count := 0
	var cleared_count := 0
	var encounter_count := 0
	var last_error := ""

	func _complete_current_interaction() -> void:
		completed_count += 1

	func _cancel_current_interaction() -> void:
		canceled_count += 1

	func _clear_transient_overlay() -> void:
		cleared_count += 1

	func _report_interaction_error(message: String) -> void:
		last_error = message
		push_error(message)

	func _start_encounter(_encounter: Encounter) -> void:
		encounter_count += 1


func _manager() -> InteractionManagerDouble:
	var manager := InteractionManagerDouble.new()
	manager.dungeon_map = DungeonMap.new()
	manager.overlay_layer = Node.new()
	manager.add_child(manager.dungeon_map)
	manager.add_child(manager.overlay_layer)
	return manager


func _node(type: MapNode.NodeType, coords := Vector2i(3, 4)) -> MapNode:
	var node := MapNode.new()
	node.type = type
	node.grid_coords = coords
	return node


func test_completed_and_canceled_dispatch_to_one_focused_seam_each() -> void:
	var manager := _manager()

	await manager._finish_interaction(GameManager.InteractionOutcome.COMPLETED)
	assert_eq(manager.completed_count, 1)
	assert_eq(manager.canceled_count, 0)

	await manager._finish_interaction(GameManager.InteractionOutcome.CANCELED)
	assert_eq(manager.completed_count, 1)
	assert_eq(manager.canceled_count, 1)
	manager.free()


func test_missing_terminal_payload_reports_context_and_remains_retryable() -> void:
	var manager := _manager()
	var node := _node(MapNode.NodeType.TERMINAL)
	manager.add_child(node)

	manager._on_map_interaction_requested(node)

	assert_push_error("terminal payload")
	assert_string_contains(manager.last_error, "(3, 4)")
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 1)
	manager.free()


func test_malformed_terminal_payload_reports_value_and_remains_retryable() -> void:
	var manager := _manager()
	var node := _node(MapNode.NodeType.TERMINAL)
	manager.add_child(node)
	manager.dungeon_map.terminal_memory[node.grid_coords] = {"facility_name": 42}

	manager._on_map_interaction_requested(node)

	assert_push_error("terminal payload")
	assert_string_contains(manager.last_error, "facility_name")
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 1)
	manager.free()


func test_malformed_encounter_payload_reports_context_and_remains_retryable() -> void:
	var manager := _manager()
	var node := _node(MapNode.NodeType.COMBAT)
	manager.add_child(node)
	manager.dungeon_map.encounter_memory[node.grid_coords] = ["attack_drones_1", false]

	manager._on_map_interaction_requested(node)

	assert_push_error("encounter payload")
	assert_string_contains(manager.last_error, "(3, 4)")
	assert_eq(manager.encounter_count, 0)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 1)
	manager.free()


func test_unknown_encounter_reports_id_and_remains_retryable() -> void:
	var manager := _manager()
	var node := _node(MapNode.NodeType.COMBAT)
	manager.add_child(node)
	manager.dungeon_map.encounter_memory[node.grid_coords] = ["definitely_missing", false, false]

	manager._on_map_interaction_requested(node)

	assert_push_error("definitely_missing")
	assert_string_contains(manager.last_error, "(3, 4)")
	assert_eq(manager.encounter_count, 0)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 1)
	manager.free()


func test_valid_encounter_payload_starts_battle_without_completing_node() -> void:
	var manager := _manager()
	var node := _node(MapNode.NodeType.COMBAT)
	manager.add_child(node)
	manager.dungeon_map.encounter_memory[node.grid_coords] = ["attack_drones_1", false, false]

	manager._on_map_interaction_requested(node)

	assert_eq(manager.encounter_count, 1)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 0)
	manager.free()


func test_missing_and_malformed_reward_payloads_remain_retryable() -> void:
	for payload in [null, {"type": LootManager.LootType.BITS}]:
		var manager := _manager()
		var node := _node(MapNode.NodeType.REWARD)
		manager.add_child(node)
		if payload != null:
			manager.dungeon_map.reward_memory[node.grid_coords] = payload

		manager._on_map_interaction_requested(node)

		assert_push_error("reward payload")
		assert_string_contains(manager.last_error, "(3, 4)")
		assert_eq(manager.completed_count, 0)
		assert_eq(manager.canceled_count, 1)
		manager.free()
