extends GutTest

const DUNGEON_MAP_SCENE := preload("res://src/map/dungeon_map.tscn")
const NAVIGATION_UX_SCENE := preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const TERMINAL_SCENE := preload("res://src/map/terminal.tscn")


func after_each() -> void:
	for action: StringName in [
		&"nav_right", &"camera_pan_right", &"zoom_in", &"recenter",
	]:
		Input.action_release(action)


func _make_map() -> DungeonMap:
	var dungeon_map := DUNGEON_MAP_SCENE.instantiate() as DungeonMap
	add_child_autofree(dungeon_map)
	dungeon_map.map_length = 4
	dungeon_map.map_height = 1
	await get_tree().process_frame
	return dungeon_map


func _make_navigation_ux() -> NavigationUXLayer:
	var navigation := NAVIGATION_UX_SCENE.instantiate() as NavigationUXLayer
	add_child_autofree(navigation)
	return navigation


func test_restore_preserves_authoritative_map_state_and_danger_vision() -> void:
	var source := await _make_map()
	await source.generate_hex_grid(false, {
		Vector2i(0, 0): MapNode.NodeType.ENTRANCE,
		Vector2i(1, 0): MapNode.NodeType.COMBAT,
		Vector2i(2, 0): MapNode.NodeType.REWARD,
		Vector2i(3, 0): MapNode.NodeType.TERMINAL,
	})
	var coords: Array = source.grid_nodes.keys()
	coords.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.y < b.y)
	var current_coords: Vector2i = coords[3]
	source.current_node = source.grid_nodes[current_coords]
	source.total_nodes = 4
	source.nodes_done = 1
	source.current_alert = 80.0

	var saved := source.get_save_data()
	var current_key := var_to_str(current_coords)
	var encounter_key := var_to_str(coords[1])
	var reward_key := var_to_str(coords[2])
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
	saved.encounter_memory[encounter_key] = ["encounter_restore", false, false]
	saved.reward_memory[reward_key] = {"type": 0, "amount": 23}

	var restored := await _make_map()
	var did_restore: bool = await restored.load_from_save_data(saved)

	assert_true(did_restore)
	assert_eq(restored.current_alert, 80.0)
	assert_eq(restored.current_node.grid_coords, current_coords)
	assert_eq(restored.current_node.type, MapNode.NodeType.TERMINAL)
	assert_eq(restored.terminal_memory[current_coords], saved.terminal_memory[current_key])
	assert_eq(restored.vision_range, 0)
	assert_eq(restored.node_gauge.max_value, 4.0)

	var resaved := restored.get_save_data()
	assert_eq(resaved.current_coords, saved.current_coords)
	assert_eq(resaved.current_alert, saved.current_alert)
	assert_eq(resaved.total_nodes, saved.total_nodes)
	assert_eq(resaved.nodes_done, saved.nodes_done)
	assert_eq(resaved.node_data, saved.node_data)
	assert_eq(resaved.terminal_memory, saved.terminal_memory)
	assert_eq(resaved.encounter_memory, saved.encounter_memory)
	assert_eq(resaved.reward_memory, saved.reward_memory)


func _prepare_navigation_map() -> Dictionary:
	var dungeon_map := await _make_map()
	await dungeon_map.generate_hex_grid(false, {
		Vector2i(0, 0): MapNode.NodeType.ENTRANCE,
		Vector2i(1, 0): MapNode.NodeType.COMBAT,
		Vector2i(2, 0): MapNode.NodeType.REWARD,
		Vector2i(3, 0): MapNode.NodeType.TERMINAL,
	})
	var nodes: Array = dungeon_map.grid_nodes.values()
	nodes.sort_custom(func(a: MapNode, b: MapNode): return a.position.x < b.position.x)
	for node: MapNode in nodes:
		node.set_state(MapNode.NodeState.REVEALED)
	dungeon_map.current_node = nodes[1]
	dungeon_map.player_cursor.position = nodes[1].position
	dungeon_map.current_map_state = DungeonMap.MapState.PLAYING
	return {map = dungeon_map, nodes = nodes}


func test_dungeon_scene_has_no_secondary_scan_cursor() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	assert_null(dungeon_map.get_node_or_null("Player/ScannerCursor"))


func test_controller_neutral_clears_preview_and_returns_reticle_to_current_node() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_not_null(dungeon_map._controller_preview_node)
	dungeon_map._reconcile_controller_navigation(Vector2.ZERO)
	assert_null(dungeon_map._controller_preview_node)
	assert_true(dungeon_map.player_reticle.visible)
	await get_tree().create_timer(0.2).timeout
	assert_eq(dungeon_map.player_reticle.position, dungeon_map.current_node.position)
	await get_tree().create_timer(0.5).timeout
	assert_false(dungeon_map.player_reticle.visible)


func test_keyboard_mode_does_not_preview_or_confirm_dungeon_nodes() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var start := dungeon_map.current_node
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	Input.action_press(&"nav_right")
	dungeon_map._process(0.016)
	Input.action_release(&"nav_right")
	assert_null(dungeon_map._controller_preview_node)
	dungeon_map._unhandled_input(_action_event(&"confirm"))
	assert_same(dungeon_map.current_node, start)


func test_mouse_hover_takes_reticle_ownership_after_controller_preview() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_not_null(dungeon_map._controller_preview_node)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	dungeon_map._on_node_hovered(nodes[0])
	dungeon_map._process(0.016)
	assert_null(dungeon_map._controller_preview_node)
	assert_eq(dungeon_map.player_reticle.position, nodes[0].position)


func test_controller_confirm_event_moves_to_previewed_node() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	var preview := dungeon_map._controller_preview_node
	assert_not_null(preview)
	dungeon_map._unhandled_input(_action_event(&"confirm"))
	assert_same(dungeon_map.current_node, preview)


func test_keyboard_confirm_event_cannot_consume_controller_preview() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	var preview := dungeon_map._controller_preview_node
	var start := dungeon_map.current_node
	assert_not_null(preview)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	dungeon_map._unhandled_input(_action_event(&"confirm"))
	assert_same(dungeon_map.current_node, start)
	assert_same(dungeon_map._controller_preview_node, preview)


func test_held_direction_is_reevaluated_after_completed_node_movement() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	for index in [2, 3]:
		nodes[index].set_state(MapNode.NodeState.COMPLETED)
		nodes[index].has_been_visited = true
		nodes[index].is_aware = true
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_same(dungeon_map._controller_preview_node, nodes[2])
	dungeon_map.confirm_preview()
	assert_same(dungeon_map.current_node, nodes[2])
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_same(dungeon_map._controller_preview_node, nodes[3])
	dungeon_map.confirm_preview()
	assert_same(dungeon_map.current_node, nodes[3])


func test_held_mapped_direction_and_repeated_controller_confirms_traverse_completed_chain() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	for node: MapNode in nodes:
		node.set_state(MapNode.NodeState.COMPLETED)
		node.has_been_visited = true
		node.is_aware = true
	dungeon_map.current_node = nodes[0]
	dungeon_map.player_cursor.position = nodes[0].position
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	Input.action_press(&"nav_right")

	for index in range(1, nodes.size()):
		dungeon_map._process(0.016)
		assert_same(dungeon_map._controller_preview_node, nodes[index])
		dungeon_map._unhandled_input(_controller_confirm_event())
		assert_same(dungeon_map.current_node, nodes[index])

	Input.action_release(&"nav_right")


func test_locked_interaction_reselects_after_unlock_without_stick_reset() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	dungeon_map.confirm_preview()
	assert_same(dungeon_map.current_node, nodes[2])
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	assert_null(dungeon_map._controller_preview_node)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_null(dungeon_map._controller_preview_node)
	dungeon_map.unlock_input()
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_same(dungeon_map._controller_preview_node, nodes[3])


func test_controller_candidates_allow_adjacent_hidden_revealed_and_completed_destinations() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	nodes[2].set_state(MapNode.NodeState.COMPLETED)
	nodes[2].has_been_visited = true

	dungeon_map.select_direction(Vector2.RIGHT)
	assert_same(dungeon_map._controller_preview_node, nodes[2])
	dungeon_map.cancel_preview()
	assert_null(dungeon_map._controller_preview_node)

	nodes[2].set_state(MapNode.NodeState.HIDDEN)
	assert_true(dungeon_map._is_controller_candidate(nodes[2]))
	assert_false(dungeon_map._is_controller_candidate(nodes[1]), "current node is not a destination")
	assert_false(dungeon_map._is_controller_candidate(nodes[3]), "non-adjacent node is not a destination")


func test_mouse_and_controller_normal_traversal_destinations_match() -> void:
	var cases := [
		{state = MapNode.NodeState.REVEALED, expected = true},
		{state = MapNode.NodeState.COMPLETED, expected = true},
		{state = MapNode.NodeState.HIDDEN, expected = true},
	]
	for case: Dictionary in cases:
		var setup := await _prepare_navigation_map()
		var dungeon_map: DungeonMap = setup.map
		var nodes: Array = setup.nodes
		var target: MapNode = nodes[2]
		target.set_state(case.state)

		assert_eq(
			dungeon_map._is_controller_candidate(target),
			dungeon_map._is_normal_traversal_destination(target),
		)
		assert_eq(dungeon_map._is_controller_candidate(target), case.expected)

		var starting_node: MapNode = dungeon_map.current_node
		dungeon_map._on_node_clicked(target)
		assert_eq(dungeon_map.current_node == target, case.expected)
		if not case.expected:
			assert_same(dungeon_map.current_node, starting_node)


func test_zero_visibility_can_move_into_hidden_adjacent_hex_and_continue_exploring() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	var hidden: MapNode = nodes[2]
	hidden.set_state(MapNode.NodeState.HIDDEN)
	hidden.is_aware = false
	dungeon_map.vision_range = 0
	dungeon_map.current_alert = DungeonMap.ALERT_MED_THRESHOLD
	watch_signals(dungeon_map)

	assert_true(dungeon_map._is_controller_candidate(hidden))
	dungeon_map._on_node_clicked(hidden)

	assert_same(dungeon_map.current_node, hidden)
	assert_true(hidden.has_been_visited)
	assert_eq(hidden.state, MapNode.NodeState.REVEALED)
	assert_signal_emitted_with_parameters(dungeon_map, &"interaction_requested", [hidden])


func test_completed_revisit_adds_half_alert_without_requesting_interaction() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	var completed: MapNode = nodes[2]
	completed.set_state(MapNode.NodeState.COMPLETED)
	completed.has_been_visited = true
	for node: MapNode in nodes:
		node.is_aware = true
	dungeon_map._calculate_alert_gain()
	dungeon_map.current_alert = 10.0
	var baseline := dungeon_map.current_alert
	watch_signals(dungeon_map)

	dungeon_map._on_node_clicked(completed)
	await get_tree().process_frame

	assert_almost_eq(dungeon_map.current_alert, baseline + dungeon_map.current_move_cost / 2.0, 0.001)
	assert_signal_not_emitted(dungeon_map, "interaction_requested")


func test_revealed_unvisited_move_adds_full_alert_and_requests_interaction() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	var target: MapNode = nodes[2]
	target.set_state(MapNode.NodeState.REVEALED)
	target.has_been_visited = false
	for node: MapNode in nodes:
		node.is_aware = true
	dungeon_map._calculate_alert_gain()
	dungeon_map.current_alert = 10.0
	var baseline := dungeon_map.current_alert
	watch_signals(dungeon_map)

	dungeon_map._on_node_clicked(target)
	await get_tree().process_frame

	assert_almost_eq(dungeon_map.current_alert, baseline + dungeon_map.current_move_cost, 0.001)
	assert_signal_emit_count(dungeon_map, "interaction_requested", 1)


func test_scan_starts_on_party_with_single_reticle() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	var expected := dungeon_map.get_viewport_rect().size * 0.5
	assert_true(dungeon_map.scan_controller.active)
	assert_lt(dungeon_map.scan_controller.pointer_position.distance_to(expected), 0.01)
	assert_eq(dungeon_map.camera.position, dungeon_map.current_node.position)
	assert_same(dungeon_map.scan_controller.selected_node, dungeon_map.current_node)
	assert_same(dungeon_map._controller_preview_node, dungeon_map.current_node)
	assert_true(dungeon_map.player_reticle.visible)
	assert_eq(dungeon_map.player_reticle.position, dungeon_map.current_node.position)


func test_scan_start_without_current_node_is_rejected_and_cancel_is_safe() -> void:
	var dungeon_map := await _make_map()
	dungeon_map.current_map_state = DungeonMap.MapState.PLAYING
	assert_null(dungeon_map.current_node)

	dungeon_map.start_targeting_mode(2)
	dungeon_map._cancel_targeting()

	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	assert_eq(dungeon_map.pending_scan_radius, 0)
	assert_false(dungeon_map.scan_controller.active)
	assert_false(dungeon_map.player_reticle.visible)
	assert_eq(
		dungeon_map.camera_controller.focus_mode,
		DungeonCameraController.FocusMode.PARTY,
	)


func test_controller_pointer_resolves_real_node_on_physics_frame() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var target: MapNode = setup.nodes[2]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	await get_tree().physics_frame
	var original := dungeon_map.scan_controller.selected_node
	var travel_delta := (
		(target.position.x - dungeon_map.current_node.position.x)
		* dungeon_map.camera.zoom.x
		/ dungeon_map.scan_controller.cursor_speed
	)
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, travel_delta)
	assert_same(dungeon_map.scan_controller.selected_node, original)
	await get_tree().physics_frame
	assert_same(dungeon_map.scan_controller.selected_node, target)
	assert_eq(dungeon_map.player_reticle.position, target.position)


func test_scan_hover_selects_nodes_in_every_visibility_state() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	dungeon_map.start_targeting_mode(1)
	var states := [
		MapNode.NodeState.HIDDEN,
		MapNode.NodeState.REVEALED,
		MapNode.NodeState.COMPLETED,
	]
	for index in states.size():
		var hovered: MapNode = nodes[index]
		hovered.set_state(states[index])
		dungeon_map._on_node_hovered(hovered)
		assert_same(dungeon_map.scan_controller.selected_node, hovered)
		assert_eq(dungeon_map.player_reticle.position, hovered.position)


func test_controller_mode_ignores_real_map_node_hover_until_physics_refresh() -> void:
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var hovered: MapNode = setup.nodes[3]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	await get_tree().physics_frame
	var selected := dungeon_map.scan_controller.selected_node
	var reticle_position := dungeon_map.player_reticle.position
	var cursor_position := navigation.cursor.position

	hovered.mouse_entered.emit()

	assert_same(dungeon_map.scan_controller.selected_node, selected)
	assert_eq(dungeon_map.player_reticle.position, reticle_position)
	assert_true(navigation.cursor.visible)
	assert_eq(navigation.cursor.position, cursor_position)
	await get_tree().physics_frame
	assert_same(dungeon_map.scan_controller.selected_node, selected)
	assert_eq(dungeon_map.player_reticle.position, reticle_position)
	assert_eq(navigation.cursor.position, cursor_position)


func test_controller_scan_keeps_cursor_centered_while_analog_input_moves_camera() -> void:
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	var physical_mouse := dungeon_map.get_viewport().get_mouse_position()
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	var expected := dungeon_map.get_viewport_rect().size * 0.5
	assert_true(navigation.cursor.visible)
	assert_lt(navigation.cursor.position.distance_to(expected), 0.01)
	assert_lt(dungeon_map.scan_controller.pointer_position.distance_to(expected), 0.01)
	assert_eq(dungeon_map.get_viewport().get_mouse_position(), physical_mouse)
	var camera_before := dungeon_map.camera.position

	dungeon_map._process_scan_navigation(Vector2.RIGHT * 0.5, Vector2.ZERO, 0.1)
	var analog_camera_delta := dungeon_map.camera.position.x - camera_before.x
	assert_gt(analog_camera_delta, 0.0)
	assert_lt(dungeon_map.scan_controller.pointer_position.distance_to(expected), 0.01)
	assert_lt(navigation.cursor.position.distance_to(expected), 0.01)
	assert_eq(dungeon_map.get_viewport().get_mouse_position(), physical_mouse)

	var camera_after_analog := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.1)
	var digital_camera_delta := dungeon_map.camera.position.x - camera_after_analog.x
	assert_gt(digital_camera_delta, analog_camera_delta)
	assert_lt(dungeon_map.scan_controller.pointer_position.distance_to(expected), 0.01)
	assert_lt(navigation.cursor.position.distance_to(expected), 0.01)
	assert_eq(dungeon_map.get_viewport().get_mouse_position(), physical_mouse)


func test_right_pan_detaches_from_world_cursor_and_left_input_slides_camera_back() -> void:
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	var viewport_center := dungeon_map.get_viewport_rect().size * 0.5
	assert_lt(navigation.cursor.position.distance_to(viewport_center), 0.01)
	var target_before_pan := dungeon_map._scan_pointer_global_world_position()
	var selection_before_pan := dungeon_map.scan_controller.selected_node

	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.LEFT, 0.1)
	await get_tree().physics_frame
	var detached_cursor_position := navigation.cursor.position
	var detached_distance := detached_cursor_position.distance_to(viewport_center)
	assert_gt(detached_distance, 1.0)
	assert_almost_eq(
		dungeon_map._scan_pointer_global_world_position().x,
		target_before_pan.x,
		0.001,
	)
	assert_almost_eq(
		dungeon_map._scan_pointer_global_world_position().y,
		target_before_pan.y,
		0.001,
	)
	assert_same(dungeon_map.scan_controller.selected_node, selection_before_pan)

	dungeon_map._process_scan_navigation(Vector2.RIGHT * 0.25, Vector2.ZERO, 0.016)
	var returning_distance := navigation.cursor.position.distance_to(viewport_center)
	assert_lt(returning_distance, detached_distance)
	assert_gt(returning_distance, 1.0, "camera returns smoothly instead of snapping")


func test_scan_mouse_motion_preserves_controller_pointer_until_consumed_click_handoff() -> void:
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	var physical_mouse := dungeon_map.get_viewport().get_mouse_position()
	dungeon_map.start_targeting_mode(1)
	var controller_position := dungeon_map.scan_controller.pointer_position
	var selected_before := dungeon_map.scan_controller.selected_node
	watch_signals(selected_before)

	InputManager._input(_mouse_motion(Vector2(10, 5)))
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.1)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
	assert_true(navigation.cursor.visible)
	assert_eq(navigation.cursor.position, controller_position)
	assert_same(dungeon_map.scan_controller.selected_node, selected_before)

	InputManager._input(_mouse_button(MOUSE_BUTTON_LEFT, true))
	assert_eq(InputManager._consumed_mouse_button, MOUSE_BUTTON_LEFT)
	InputManager._input(_mouse_button(MOUSE_BUTTON_LEFT, false))
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.1)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.KEYBOARD_MOUSE)
	assert_eq(InputManager.get_presentation_mode(), InputManager.PresentationMode.POINTER)
	assert_false(navigation.cursor.visible)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.TARGETING)
	assert_same(dungeon_map.scan_controller.selected_node, selected_before)
	assert_signal_not_emitted(selected_before, &"node_clicked")
	assert_eq(dungeon_map.get_viewport().get_mouse_position(), physical_mouse)

	var second_click := _mouse_button(MOUSE_BUTTON_LEFT, true)
	InputManager._input(second_click)
	selected_before._input_event(dungeon_map.get_viewport(), second_click, 0)
	InputManager._input(_mouse_button(MOUSE_BUTTON_LEFT, false))
	assert_signal_emitted(selected_before, &"node_clicked")
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)


func test_pointer_gap_preserves_last_valid_scan_selection() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var selected: MapNode = setup.nodes[1]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	await get_tree().physics_frame
	dungeon_map._apply_scan_selection(selected)
	var previous_reticle := dungeon_map.player_reticle.position
	var gap_position := selected.get_global_transform_with_canvas().origin + Vector2(0, 100)
	dungeon_map.scan_controller.sync_pointer(gap_position, dungeon_map.get_viewport_rect().size)

	await get_tree().physics_frame

	assert_same(dungeon_map.scan_controller.selected_node, selected)
	assert_eq(dungeon_map.player_reticle.position, previous_reticle)


func test_controller_can_select_and_scan_hidden_hex_with_live_map_transform() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.position = Vector2(600, 400)
	dungeon_map.scale = Vector2.ONE * 0.625
	var nodes: Array = setup.nodes
	var hidden: MapNode = nodes[2]
	hidden.set_state(MapNode.NodeState.HIDDEN)
	var party_node := dungeon_map.current_node
	var alert := dungeon_map.current_alert
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	await get_tree().physics_frame
	var travel_delta := (
		(hidden.position.x - dungeon_map.current_node.position.x)
		* dungeon_map.camera.zoom.x
		/ dungeon_map.scan_controller.cursor_speed
	)
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, travel_delta)
	await get_tree().physics_frame
	assert_same(dungeon_map._controller_preview_node, hidden)
	watch_signals(dungeon_map)
	dungeon_map._unhandled_input(_action_event(&"confirm"))
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	await get_tree().create_timer(0.3).timeout
	assert_signal_emitted(dungeon_map, &"scan_performed")
	assert_eq(hidden.state, MapNode.NodeState.REVEALED)
	assert_same(dungeon_map.current_node, party_node)
	assert_eq(dungeon_map.current_alert, alert)


func test_mouse_can_hover_and_click_hidden_scan_center() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var hidden: MapNode = setup.nodes[2]
	hidden.set_state(MapNode.NodeState.HIDDEN)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	dungeon_map.start_targeting_mode(1)
	dungeon_map._on_node_hovered(hidden)
	assert_same(dungeon_map._controller_preview_node, hidden)
	assert_eq(dungeon_map.player_reticle.position, hidden.position)
	dungeon_map._on_node_clicked(hidden)
	await get_tree().create_timer(0.3).timeout
	assert_eq(hidden.state, MapNode.NodeState.REVEALED)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)


func test_mouse_hover_becomes_controller_reticle_origin_without_extra_cursor() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var hovered: MapNode = setup.nodes[2]
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	dungeon_map.start_targeting_mode(1)
	dungeon_map._on_node_hovered(hovered)
	assert_same(dungeon_map.scan_controller.selected_node, hovered)
	assert_same(dungeon_map._controller_preview_node, hovered)
	assert_eq(dungeon_map.player_reticle.position, hovered.position)
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.016)
	assert_same(dungeon_map.scan_controller.selected_node, hovered)
	assert_eq(dungeon_map.player_reticle.position, hovered.position)


func test_select_direction_does_not_replace_active_scan_selection() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var selected: MapNode = setup.nodes[2]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_selected(selected)
	dungeon_map._sync_scan_selection(false)

	dungeon_map.select_direction(Vector2.RIGHT)

	assert_same(dungeon_map._controller_preview_node, selected)
	assert_same(dungeon_map.scan_controller.selected_node, selected)
	assert_eq(dungeon_map.player_reticle.position, selected.position)


func test_opening_modal_cancels_active_scan_and_returns_party_focus() -> void:
	InputManager._input(_joy_button())
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var selected: MapNode = setup.nodes[2]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_selected(selected)
	dungeon_map._sync_scan_selection(false)
	dungeon_map.camera.position = selected.position
	var expected := dungeon_map._calculate_hybrid_position(dungeon_map.camera.zoom)
	watch_signals(dungeon_map)

	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	dungeon_map._process(0.016)
	assert_true(navigation.is_top_modal(terminal))
	assert_false(dungeon_map.scan_controller.active)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	assert_eq(dungeon_map.pending_scan_radius, 0)
	assert_false(dungeon_map.player_reticle.visible)
	assert_eq(
		dungeon_map.camera_controller.focus_mode,
		DungeonCameraController.FocusMode.PARTY,
	)
	assert_signal_emit_count(dungeon_map, &"scan_canceled", 1)
	assert_false(navigation.cursor.visible)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	await get_tree().create_timer(dungeon_map.camera_smooth_speed + 0.05).timeout
	assert_almost_eq(dungeon_map.camera.position.x, expected.x, 0.01)
	assert_almost_eq(dungeon_map.camera.position.y, expected.y, 0.01)
	terminal.queue_free()
	await get_tree().process_frame


func test_scan_cancel_restores_cursor_when_handler_opens_focusless_terminal() -> void:
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	assert_true(navigation.cursor.visible)
	var terminal := TERMINAL_SCENE.instantiate()
	dungeon_map.scan_canceled.connect(func() -> void: add_child(terminal), CONNECT_ONE_SHOT)

	dungeon_map.cancel_preview()

	assert_true(navigation.is_top_modal(terminal))
	assert_false(navigation.cursor.visible)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	terminal.queue_free()
	await get_tree().process_frame


func test_scan_cancel_preserves_focus_claimed_by_modal() -> void:
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	var modal := Control.new()
	var focus_target := Button.new()
	modal.add_child(focus_target)
	add_child(modal)
	navigation.push_modal(modal, focus_target)
	assert_same(navigation.get_focus_target(), focus_target)
	assert_true(NavigationFocus._states.has(focus_target.get_instance_id()))

	dungeon_map._process(0.016)

	assert_false(dungeon_map.scan_controller.active)
	assert_false(navigation.cursor.visible)
	assert_same(navigation.get_focus_target(), focus_target)
	assert_true(NavigationFocus._states.has(focus_target.get_instance_id()))
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	navigation.pop_modal(modal)
	modal.queue_free()
	await get_tree().process_frame


func test_open_modal_suppresses_playing_map_events_without_canceling() -> void:
	InputManager._input(_joy_button())
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var selected: MapNode = setup.nodes[3]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(2.0, 2.0)
	dungeon_map.camera.position = dungeon_map._get_clamped_camera_pos(
		selected.position,
		dungeon_map.camera.zoom,
	)
	watch_signals(dungeon_map)

	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	assert_true(navigation.is_top_modal(terminal))
	dungeon_map._process(0.016)

	var zoom_before := dungeon_map.camera.zoom
	var camera_before := dungeon_map.camera.position
	for action: StringName in [&"zoom_in", &"recenter", &"cancel"]:
		dungeon_map._unhandled_input(_action_event(action))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	dungeon_map._input(wheel)
	var magnify := InputEventMagnifyGesture.new()
	magnify.factor = 1.5
	dungeon_map._input(magnify)
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(8.0, -5.0)
	dungeon_map._input(pan)

	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	assert_false(dungeon_map.scan_controller.active)
	assert_signal_emit_count(dungeon_map, &"scan_canceled", 0)
	assert_eq(dungeon_map.camera.zoom, zoom_before)
	assert_eq(dungeon_map.camera.position, camera_before)
	terminal.queue_free()
	await get_tree().process_frame


func test_scan_screen_position_has_distinct_global_world_and_map_local_conversions() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.position = Vector2(960, 540)
	var target: MapNode = setup.nodes[2]
	dungeon_map.camera.force_update_scroll()
	var pointer_screen_position := target.get_global_transform_with_canvas().origin
	dungeon_map.scan_controller.pointer_position = pointer_screen_position

	assert_almost_eq(
		dungeon_map._scan_pointer_global_world_position().x,
		target.global_position.x,
		0.001,
	)
	assert_almost_eq(
		dungeon_map._scan_pointer_global_world_position().y,
		target.global_position.y,
		0.001,
	)
	assert_almost_eq(dungeon_map._scan_pointer_map_position().x, target.position.x, 0.001)
	assert_almost_eq(dungeon_map._scan_pointer_map_position().y, target.position.y, 0.001)


func test_centered_scan_camera_speed_is_constant_in_screen_space_across_zoom() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	var viewport_size := dungeon_map.get_viewport_rect().size
	var before := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.1)
	var expected_world_delta := dungeon_map.scan_controller.cursor_speed * 0.1 / 5.0
	assert_almost_eq(dungeon_map.camera.position.x - before.x, expected_world_delta, 0.001)
	assert_lt(
		dungeon_map.scan_controller.pointer_position.distance_to(viewport_size * 0.5),
		0.01,
	)


func test_releasing_scan_direction_immediately_stops_camera() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	var viewport_size := dungeon_map.get_viewport_rect().size
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.016)
	var after_pressure := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.1)
	assert_eq(dungeon_map.camera.position, after_pressure)
	assert_lt(
		dungeon_map.scan_controller.pointer_position.distance_to(viewport_size * 0.5),
		0.01,
	)


func test_holding_scan_direction_keeps_moving_camera_under_centered_cursor() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	var viewport_size := dungeon_map.get_viewport_rect().size
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.016)
	var after_first_frame := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.016)
	assert_lt(
		dungeon_map.scan_controller.pointer_position.distance_to(viewport_size * 0.5),
		0.01,
	)
	assert_gt(dungeon_map.camera.position.x, after_first_frame.x)


func test_centered_scan_motion_takes_priority_over_right_stick() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	var before := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.LEFT, 0.1)
	assert_gt(dungeon_map.camera.position.x, before.x)


func test_releasing_right_stick_requires_scan_direction_to_resume_centered_motion() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.LEFT, 0.1)
	var after_pan := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.1)
	assert_eq(dungeon_map.camera.position, after_pan)
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.016)
	assert_gt(
		dungeon_map.camera.position.x,
		after_pan.x,
		"active scan direction resumes centered camera motion after right-stick release",
	)


func test_scan_zoom_reframes_distant_stationary_scanner_without_party_pull() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var distant: MapNode = setup.nodes[3]
	dungeon_map.max_zoom = 5.0
	dungeon_map.camera.zoom = Vector2(4.0, 4.0)
	dungeon_map.camera.position = dungeon_map.current_node.position
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_selected(distant)
	dungeon_map._controller_scan_map_position = distant.position
	dungeon_map._sync_scan_selection(false)
	var final_zoom_value := minf(dungeon_map.camera.zoom.x + 1.0, dungeon_map.max_zoom)
	var final_zoom := Vector2.ONE * final_zoom_value
	var expected := dungeon_map._get_clamped_camera_pos(
		dungeon_map.camera_controller.desired_scanner_position(
			dungeon_map.scan_controller.selected_node.position,
			dungeon_map.camera.position,
			dungeon_map.get_viewport_rect().size,
			final_zoom,
		),
		final_zoom,
	)
	var party_target := dungeon_map._calculate_hybrid_position(final_zoom)
	assert_ne(expected, party_target, "fixture distinguishes scanner framing from party framing")

	dungeon_map._zoom_camera(1.0)

	assert_eq(dungeon_map.camera.position, expected)
	await get_tree().create_timer(0.35).timeout
	assert_eq(dungeon_map.camera.zoom, final_zoom)
	assert_eq(dungeon_map.camera.position, expected)
	var half_dead_world := (
		dungeon_map.get_viewport_rect().size
		* dungeon_map.scan_dead_zone_ratio
		* 0.5
		/ final_zoom
	)
	var scanner_offset := dungeon_map.scan_controller.selected_node.position - dungeon_map.camera.position
	assert_true(absf(scanner_offset.x) <= half_dead_world.x + 0.001)
	assert_true(absf(scanner_offset.y) <= half_dead_world.y + 0.001)


func test_scan_confirmation_locks_briefly_then_returns_camera_to_party() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var target: MapNode = setup.nodes[3]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_selected(target)
	dungeon_map._sync_scan_selection(false)
	dungeon_map.camera.position = target.position
	var expected := dungeon_map._calculate_hybrid_position(dungeon_map.camera.zoom)
	dungeon_map.confirm_preview()
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	await get_tree().create_timer(0.15).timeout
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	await get_tree().create_timer(0.15).timeout
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	await get_tree().create_timer(dungeon_map.camera_smooth_speed + 0.05).timeout
	assert_almost_eq(dungeon_map.camera.position.x, expected.x, 0.01)
	assert_almost_eq(dungeon_map.camera.position.y, expected.y, 0.01)


func test_scan_cancel_returns_camera_to_party_without_consuming_scan() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.camera.position = setup.nodes[3].position
	var expected := dungeon_map._calculate_hybrid_position(dungeon_map.camera.zoom)
	watch_signals(dungeon_map)
	dungeon_map.cancel_preview()
	assert_signal_emitted(dungeon_map, &"scan_canceled")
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	await get_tree().create_timer(dungeon_map.camera_smooth_speed + 0.05).timeout
	assert_almost_eq(dungeon_map.camera.position.x, expected.x, 0.01)
	assert_almost_eq(dungeon_map.camera.position.y, expected.y, 0.01)


func test_modal_takeover_clears_scan_transient_state() -> void:
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.scan_dead_zone_ratio = 0.1
	dungeon_map.start_targeting_mode(1)
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.016)
	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	dungeon_map._process(0.1)
	assert_true(navigation.has_open_modal())
	assert_false(dungeon_map.scan_controller.active)
	assert_null(dungeon_map.scan_controller.selected_node)
	assert_null(dungeon_map._controller_preview_node)
	assert_false(dungeon_map.player_reticle.visible)
	terminal.queue_free()
	await get_tree().process_frame


func test_dungeon_navigation_actions_keep_controller_dpad_fallback() -> void:
	var expected := {
		&"nav_up": JOY_BUTTON_DPAD_UP,
		&"nav_down": JOY_BUTTON_DPAD_DOWN,
		&"nav_left": JOY_BUTTON_DPAD_LEFT,
		&"nav_right": JOY_BUTTON_DPAD_RIGHT,
	}
	for action: StringName in expected:
		var found := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == expected[action]:
				found = true
				break
		assert_true(found, "%s keeps its controller D-pad event" % action)


func test_locked_state_suppresses_selection_camera_and_confirmation() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var start_node := dungeon_map.current_node
	var start_camera := dungeon_map.camera.position
	var start_zoom := dungeon_map.camera.zoom
	dungeon_map.select_direction(Vector2.RIGHT)
	dungeon_map.current_map_state = DungeonMap.MapState.LOCKED
	Input.action_press(&"camera_pan_right")
	Input.action_press(&"zoom_in")
	Input.action_press(&"recenter")
	dungeon_map._process(1.0)
	Input.action_release(&"camera_pan_right")
	Input.action_release(&"zoom_in")
	Input.action_release(&"recenter")
	for action: StringName in [&"nav_left", &"confirm", &"cancel", &"zoom_in", &"recenter"]:
		dungeon_map._unhandled_input(_action_event(action))
	assert_null(dungeon_map._controller_preview_node)
	assert_same(dungeon_map.current_node, start_node)
	assert_eq(dungeon_map.camera.position, start_camera)
	assert_eq(dungeon_map.camera.zoom, start_zoom)


func test_camera_pan_is_delta_scaled_zoom_is_clamped_and_recenter_targets_current_node() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.camera_pan_speed = 100.0
	dungeon_map.camera.position = Vector2.ZERO
	dungeon_map.process_controller_camera(Vector2.RIGHT, 0.25)
	var quarter_delta := dungeon_map.camera.position.x
	dungeon_map.camera.position = Vector2.ZERO
	dungeon_map.process_controller_camera(Vector2.RIGHT, 0.5)
	assert_almost_eq(dungeon_map.camera.position.x, quarter_delta * 2.0, 0.01)

	dungeon_map.camera.zoom = Vector2(dungeon_map.max_zoom, dungeon_map.max_zoom)
	dungeon_map._zoom_camera(dungeon_map.zoom_step)
	await get_tree().create_timer(0.35).timeout
	assert_eq(dungeon_map.camera.zoom, Vector2(dungeon_map.max_zoom, dungeon_map.max_zoom))
	dungeon_map.camera.position = Vector2(9999, 9999)
	dungeon_map.recenter_camera()
	assert_eq(dungeon_map.camera.position, dungeon_map._get_clamped_camera_pos(dungeon_map.current_node.position, dungeon_map.camera.zoom))


func test_trackpad_pan_during_party_zoom_retains_gesture_position() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.max_zoom = 5.0
	dungeon_map.camera.zoom = Vector2(4.0, 4.0)
	dungeon_map.camera.position = Vector2.ZERO
	dungeon_map._zoom_camera(1.0)
	var position_before_gesture := dungeon_map.camera.position
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(8.0, -5.0)
	var expected := dungeon_map._get_clamped_camera_pos(
		position_before_gesture + pan.delta * 20.0 * dungeon_map.camera.zoom.x,
		dungeon_map.camera.zoom,
	)
	assert_ne(
		expected,
		dungeon_map._calculate_hybrid_position(Vector2(5.0, 5.0)),
		"fixture distinguishes the gesture from the stale party target",
	)

	dungeon_map._input(pan)
	assert_eq(dungeon_map.camera.position, expected)

	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout

	assert_eq(dungeon_map.camera.zoom, Vector2(5.0, 5.0))
	assert_eq(dungeon_map.camera.position, expected)


func test_battle_visuals_cancel_camera_motion_and_restore_party_focus() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map._zoom_camera(dungeon_map.zoom_step)
	assert_true(dungeon_map.camera_controller.has_active_motion())
	await dungeon_map.enter_battle_visuals(0.0)
	assert_false(dungeon_map.camera_controller.has_active_motion())
	dungeon_map.exit_battle_visuals(0.0)
	await get_tree().process_frame
	assert_eq(
		dungeon_map.camera_controller.focus_mode,
		DungeonCameraController.FocusMode.PARTY,
	)


func test_arrow_keys_drive_all_camera_directions_without_selecting_nodes() -> void:
	var cases := [
		[KEY_LEFT, Vector2.LEFT],
		[KEY_RIGHT, Vector2.RIGHT],
		[KEY_UP, Vector2.UP],
		[KEY_DOWN, Vector2.DOWN],
	]
	for item: Array in cases:
		var setup := await _prepare_navigation_map()
		var dungeon_map: DungeonMap = setup.map
		dungeon_map.camera.zoom = Vector2(10.0, 10.0)
		dungeon_map.camera.position = dungeon_map._get_clamped_camera_pos(Vector2.ZERO, dungeon_map.camera.zoom)
		dungeon_map.select_direction(Vector2.RIGHT)
		var start_camera := dungeon_map.camera.position
		var start_node := dungeon_map.current_node
		var start_selection := dungeon_map.player_cursor.position
		var arrow := _physical_key(item[0])
		Input.parse_input_event(arrow)
		await get_tree().process_frame
		dungeon_map._process(0.1)
		var end_camera := dungeon_map.camera.position
		var release := arrow.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
		await get_tree().process_frame

		var displacement := end_camera - start_camera
		var direction: Vector2 = item[1]
		assert_gt(displacement.dot(direction), 0.0, "arrow pans the real camera in its signed direction")
		assert_almost_eq(displacement.cross(direction), 0.0, 0.01, "arrow does not pan across the requested axis")
		assert_same(dungeon_map.current_node, start_node, "arrow does not change the current node")
		assert_null(dungeon_map._controller_preview_node, "keyboard mode clears controller preview")
		assert_eq(dungeon_map.player_cursor.position, start_selection, "arrow does not change controller selection")


func test_map_registers_global_adapter_preserves_preview_without_world_cursor_and_publishes_state_hints() -> void:
	InputManager._input(_joy_button())
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var outsider := Button.new()
	add_child_autofree(outsider)
	assert_same(navigation._adapter, dungeon_map)

	Input.action_press(&"nav_right")
	dungeon_map._process(0.016)
	var preview: MapNode = dungeon_map._controller_preview_node
	assert_not_null(preview)
	assert_true(dungeon_map.player_reticle.visible)
	assert_false(navigation.cursor.visible)
	outsider.grab_focus()
	await get_tree().process_frame
	assert_false(navigation.cursor.visible, "focus changes cannot reveal the scan pointer")
	assert_same(dungeon_map._controller_preview_node, preview)
	Input.action_release(&"nav_right")
	assert_eq(_hint_actions(navigation), [&"confirm", &"cancel", &"camera_pan_right", &"zoom_in", &"zoom_out", &"recenter"])
	dungeon_map.current_map_state = DungeonMap.MapState.LOCKED
	dungeon_map._publish_controller_hints()
	for index in navigation.hint_bar.get_hint_count():
		assert_false(navigation.hint_bar.get_hint(index).enabled)
	dungeon_map.unlock_input()

	dungeon_map.start_targeting_mode(1)
	assert_eq(navigation.hint_bar.get_hint(0).label.text, "Scan")
	dungeon_map.cancel_preview()
	assert_eq(
		dungeon_map.camera_controller.focus_mode,
		DungeonCameraController.FocusMode.PARTY,
	)
	assert_null(dungeon_map._controller_preview_node)
	assert_false(dungeon_map.player_reticle.visible)
	dungeon_map.queue_free()
	await get_tree().process_frame
	assert_null(navigation._adapter)
	assert_false(navigation.cursor.visible)
	assert_eq(navigation.hint_bar.get_hint_count(), 0)


func test_unconfigured_map_can_exit_without_camera_controller() -> void:
	var dungeon_map := DungeonMap.new()
	dungeon_map._exit_tree()
	dungeon_map.free()
	assert_false(is_instance_valid(dungeon_map))


func test_terminal_modal_temporarily_owns_cursor_then_restores_live_map_adapter() -> void:
	InputManager._input(_joy_button())
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	Input.action_press(&"nav_right")
	dungeon_map._process(0.016)
	assert_not_null(dungeon_map._controller_preview_node)
	assert_false(navigation.cursor.visible, "map preview uses its reticle, not the scan pointer")

	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	dungeon_map._process(0.016)
	assert_true(navigation.is_top_modal(terminal))
	assert_null(dungeon_map._controller_preview_node)
	dungeon_map._process(0.016)
	assert_null(dungeon_map._controller_preview_node, "held input cannot navigate behind modal")
	var first_protocol: TerminalProtocolRow = terminal.get_protocol_row(0)
	assert_eq(first_protocol.focus_mode, Control.FOCUS_NONE)
	assert_false(first_protocol.has_focus())
	assert_null(get_viewport().gui_get_focus_owner())
	assert_null(navigation.get_focus_target())
	assert_false(navigation.cursor.visible)
	assert_eq(navigation.hint_bar.get_hint_count(), 0)
	assert_same(navigation._adapter, dungeon_map)

	terminal.queue_free()
	await get_tree().process_frame
	dungeon_map._process(0.016)
	assert_same(navigation._adapter, dungeon_map, "closing a modal keeps the live dungeon adapter registered")
	assert_not_null(dungeon_map._controller_preview_node, "held input resumes after modal closes")
	assert_false(navigation.cursor.visible)
	assert_eq(_hint_actions(navigation), [&"confirm", &"cancel", &"camera_pan_right", &"zoom_in", &"zoom_out", &"recenter"])
	Input.action_release(&"nav_right")


func test_map_adapter_restore_keeps_scan_pointer_hidden() -> void:
	InputManager._input(_joy_button())
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.navigation_focus_restored()
	assert_false(navigation.cursor.visible)


func test_ordinary_map_navigation_never_shows_scan_pointer() -> void:
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.select_direction(Vector2.RIGHT)
	assert_false(navigation.cursor.visible)

	var motion := _mouse_motion(Vector2(10, 0))
	InputManager._input(motion)
	assert_false(navigation.cursor.visible)

	var navigation_key := InputEventKey.new()
	navigation_key.physical_keycode = KEY_D
	navigation_key.pressed = true
	InputManager._input(navigation_key)
	assert_false(navigation.cursor.visible)
	dungeon_map._process(0.016)
	assert_null(dungeon_map._controller_preview_node)


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _joy_button() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	return event


func _controller_confirm_event() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func _physical_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _mouse_motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event


func _mouse_button(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _hint_actions(navigation: NavigationUXLayer) -> Array[StringName]:
	var actions: Array[StringName] = []
	for index in navigation.hint_bar.get_hint_count():
		actions.append(navigation.hint_bar.get_hint(index).action)
	return actions
