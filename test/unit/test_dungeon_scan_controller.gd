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


func test_move_is_delta_scaled_screen_speed_and_zoom_adjusted() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2.ZERO, Rect2(-1000, -1000, 2000, 2000))
	assert_eq(controller.move(Vector2.RIGHT, 0.5, Vector2(2, 2)), Vector2(150, 0))
	var before := controller.position
	controller.move(Vector2(1, 1), 0.5, Vector2.ONE)
	assert_almost_eq(controller.position.distance_to(before), 300.0, 0.001)


func test_position_clamps_to_generated_bounds() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2.ZERO, Rect2(-100, -50, 200, 100))
	assert_eq(controller.set_position(Vector2(500, -500)), Vector2(100, -50))
	controller.move(Vector2.LEFT, 10.0, Vector2.ONE)
	assert_eq(controller.position, Vector2(-100, -50))


func test_bounds_for_nodes_uses_all_generated_centers() -> void:
	var left := await _node(Vector2(-80, 20), Vector2i(0, 0))
	var right := await _node(Vector2(120, -40), Vector2i(1, 0))
	assert_eq(
		DungeonScanController.bounds_for_nodes([right, left]),
		Rect2(Vector2(-80, -40), Vector2(200, 60)),
	)


func test_nearest_selection_includes_hidden_and_breaks_ties_by_coordinates() -> void:
	var controller := DungeonScanController.new()
	var high := await _node(Vector2(10, 0), Vector2i(2, 0), MapNode.NodeState.REVEALED)
	var low_hidden := await _node(Vector2(-10, 0), Vector2i(1, 0), MapNode.NodeState.HIDDEN)
	controller.begin(Vector2.ZERO, DungeonScanController.bounds_for_nodes([high, low_hidden]))
	assert_same(controller.select_nearest([high, low_hidden]), low_hidden)
	assert_eq(low_hidden.state, MapNode.NodeState.HIDDEN)


func test_empty_selection_returns_null() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2.ZERO, Rect2(Vector2.ZERO, Vector2.ZERO))
	assert_null(controller.select_nearest([]))


func test_camera_stays_still_inside_proportional_dead_zone() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2(250, 200), Rect2(-1000, -1000, 2000, 2000))
	assert_eq(
		controller.desired_camera_position(Vector2.ZERO, Vector2(1000, 800), Vector2.ONE),
		Vector2.ZERO,
	)


func test_camera_moves_minimum_distance_to_dead_zone_boundary() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2(400, -300), Rect2(-1000, -1000, 2000, 2000))
	assert_eq(
		controller.desired_camera_position(Vector2.ZERO, Vector2(1000, 800), Vector2.ONE),
		Vector2(100, -60),
	)


func test_camera_dead_zone_scales_with_zoom_and_viewport() -> void:
	var controller := DungeonScanController.new()
	controller.begin(Vector2(200, 0), Rect2(-1000, -1000, 2000, 2000))
	assert_eq(
		controller.desired_camera_position(Vector2.ZERO, Vector2(1000, 800), Vector2(2, 2)),
		Vector2(50, 0),
	)
	controller.set_position(Vector2(350, 0))
	assert_eq(
		controller.desired_camera_position(Vector2.ZERO, Vector2(2000, 800), Vector2.ONE),
		Vector2.ZERO,
	)
