extends GutTest

const MAP_NODE_SCENE := preload("res://src/map/map_node.tscn")


func _node(position: Vector2, coords: Vector2i, state := MapNode.NodeState.HIDDEN) -> MapNode:
	var node := MAP_NODE_SCENE.instantiate() as MapNode
	node.position = position
	node.grid_coords = coords
	add_child_autofree(node)
	await get_tree().process_frame
	node.set_state(state)
	return node


func test_begin_initializes_pointer_and_selection_and_stop_clears_state() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i.ZERO)
	var controller := DungeonScanController.new()
	controller.begin(Vector2(320, 180), Vector2(640, 360), origin)
	assert_true(controller.active)
	assert_eq(controller.pointer_position, Vector2(320, 180))
	assert_same(controller.selected_node, origin)
	controller.stop()
	assert_false(controller.active)
	assert_null(controller.selected_node)


func test_pointer_motion_is_delta_scaled_and_speed_limited() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i.ZERO)
	var controller := DungeonScanController.new()
	controller.cursor_speed = 600.0
	controller.begin(Vector2(100, 100), Vector2(1000, 800), origin)
	assert_eq(
		controller.move_pointer(Vector2.RIGHT, 0.5, Vector2(1000, 800)),
		Vector2(400, 100),
	)
	controller.sync_pointer(Vector2(100, 100), Vector2(1000, 800))
	var diagonal := controller.move_pointer(Vector2.ONE, 0.5, Vector2(1000, 800))
	assert_almost_eq(diagonal.distance_to(Vector2(100, 100)), 300.0, 0.001)


func test_begin_and_pointer_motion_clamp_to_viewport_bounds() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i.ZERO)
	var controller := DungeonScanController.new()
	controller.begin(Vector2(-10, 500), Vector2(640, 360), origin)
	assert_eq(controller.pointer_position, Vector2(0, 359))
	assert_eq(
		controller.move_pointer(Vector2.RIGHT, 10.0, Vector2(640, 360)),
		Vector2(639, 359),
	)


func test_neutral_input_and_non_positive_delta_preserve_pointer_position() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i.ZERO)
	var controller := DungeonScanController.new()
	controller.begin(Vector2(120, 80), Vector2(640, 360), origin)
	assert_eq(controller.move_pointer(Vector2.ZERO, 1.0, Vector2(640, 360)), Vector2(120, 80))
	assert_eq(controller.move_pointer(Vector2.RIGHT, 0.0, Vector2(640, 360)), Vector2(120, 80))
	assert_eq(controller.move_pointer(Vector2.RIGHT, -1.0, Vector2(640, 360)), Vector2(120, 80))


func test_sync_pointer_clamps_mouse_position_and_next_move_continues_from_it() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i.ZERO)
	var controller := DungeonScanController.new()
	controller.cursor_speed = 600.0
	controller.begin(Vector2.ZERO, Vector2(640, 360), origin)
	assert_eq(controller.sync_pointer(Vector2(1000, -20), Vector2(640, 360)), Vector2(639, 0))
	assert_eq(controller.move_pointer(Vector2.LEFT, 0.1, Vector2(640, 360)), Vector2(579, 0))


func test_set_selected_stores_nodes_regardless_of_reveal_state() -> void:
	var hidden := await _node(Vector2(100, 0), Vector2i(10, 10), MapNode.NodeState.HIDDEN)
	var revealed := await _node(Vector2(-100, 0), Vector2i(-10, -10), MapNode.NodeState.REVEALED)
	var completed := await _node(Vector2(0, 100), Vector2i(0, 20), MapNode.NodeState.COMPLETED)
	var controller := DungeonScanController.new()
	assert_same(controller.set_selected(hidden), hidden)
	assert_same(controller.set_selected(revealed), revealed)
	assert_same(controller.set_selected(completed), completed)


func test_stop_disables_motion_and_restart_has_fresh_pointer_state() -> void:
	var first := await _node(Vector2.ZERO, Vector2i.ZERO)
	var second := await _node(Vector2(100, 0), Vector2i.ONE)
	var controller := DungeonScanController.new()
	controller.begin(Vector2(100, 100), Vector2(640, 360), first)
	controller.move_pointer(Vector2.RIGHT, 0.1, Vector2(640, 360))
	controller.stop()
	assert_false(controller.active)
	assert_null(controller.selected_node)
	assert_eq(controller.move_pointer(Vector2.RIGHT, 1.0, Vector2(640, 360)), Vector2(160, 100))
	controller.begin(Vector2(20, 30), Vector2(640, 360), second)
	assert_eq(controller.pointer_position, Vector2(20, 30))
	assert_same(controller.selected_node, second)
