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


func test_begin_selects_origin_and_stop_clears_transient_state() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i.ZERO)
	var controller := DungeonScanController.new()
	controller.begin(origin)
	assert_true(controller.active)
	assert_same(controller.selected_node, origin)
	controller.stop()
	assert_false(controller.active)
	assert_null(controller.selected_node)


func test_direction_selects_adjacent_hidden_hex_without_jumping_over_it() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i(0, 0))
	var adjacent := await _node(Vector2(100, 0), Vector2i(1, 0), MapNode.NodeState.HIDDEN)
	var distant := await _node(Vector2(200, 0), Vector2i(2, 0), MapNode.NodeState.REVEALED)
	var controller := DungeonScanController.new()
	controller.begin(origin)
	assert_same(controller.process_direction(Vector2.RIGHT, [origin, distant, adjacent], 0.0), adjacent)
	assert_eq(adjacent.state, MapNode.NodeState.HIDDEN)


func test_direction_prefers_alignment_then_coordinates_for_neighbor_tie() -> void:
	var origin := await _node(Vector2.ZERO, Vector2i(0, 0))
	var upper := await _node(Vector2(80, -50), Vector2i(0, -1))
	var lower := await _node(Vector2(80, 50), Vector2i(0, 1))
	var controller := DungeonScanController.new()
	controller.begin(origin)
	assert_same(controller.process_direction(Vector2.RIGHT, [lower, origin, upper], 0.0), upper)


func test_held_direction_repeats_after_delay() -> void:
	var first := await _node(Vector2.ZERO, Vector2i(0, 0))
	var second := await _node(Vector2(100, 0), Vector2i(1, 0))
	var third := await _node(Vector2(200, 0), Vector2i(2, 0))
	var controller := DungeonScanController.new()
	controller.begin(first)
	assert_same(controller.process_direction(Vector2.RIGHT, [first, second, third], 0.0), second)
	assert_same(controller.process_direction(Vector2.RIGHT, [first, second, third], 0.1), second)
	assert_same(
		controller.process_direction(Vector2.RIGHT, [first, second, third], DungeonScanController.REPEAT_DELAY),
		third,
	)


func test_changed_direction_steps_immediately_without_waiting_for_repeat() -> void:
	var center := await _node(Vector2.ZERO, Vector2i(0, 0))
	var right := await _node(Vector2(100, 0), Vector2i(1, 0))
	var above_right := await _node(Vector2(50, -100), Vector2i(1, -1))
	var controller := DungeonScanController.new()
	controller.begin(center)
	assert_same(controller.process_direction(Vector2.RIGHT, [center, right, above_right], 0.0), right)
	assert_same(controller.process_direction(Vector2.UP, [center, right, above_right], 0.0), above_right)


func test_map_edge_holds_last_hex_without_wrap_or_warp() -> void:
	var left := await _node(Vector2.ZERO, Vector2i(0, 0))
	var right := await _node(Vector2(100, 0), Vector2i(1, 0))
	var controller := DungeonScanController.new()
	controller.begin(left)
	assert_same(controller.process_direction(Vector2.RIGHT, [left, right], 0.0), right)
	for repeat in range(5):
		assert_same(
			controller.process_direction(Vector2.RIGHT, [left, right], DungeonScanController.REPEAT_DELAY),
			right,
		)


func test_neutral_input_resets_repeat_and_mouse_selection_becomes_controller_origin() -> void:
	var left := await _node(Vector2.ZERO, Vector2i(0, 0))
	var right := await _node(Vector2(100, 0), Vector2i(1, 0))
	var controller := DungeonScanController.new()
	controller.begin(left)
	assert_same(controller.set_selected(right), right)
	assert_same(controller.process_direction(Vector2.ZERO, [left, right], 1.0), right)
	assert_same(controller.process_direction(Vector2.LEFT, [left, right], 0.0), left)
