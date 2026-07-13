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
	InputManager._set_cursor_behavior(InputManager.CursorBehavior.SNAPPED)
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
	InputManager._set_cursor_behavior(InputManager.CursorBehavior.FREE)
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
	dungeon_map.start_targeting_mode(1)
	assert_true(dungeon_map.scan_controller.active)
	assert_same(dungeon_map.scan_controller.selected_node, dungeon_map.current_node)
	assert_same(dungeon_map._controller_preview_node, dungeon_map.current_node)
	assert_true(dungeon_map.player_reticle.visible)
	assert_eq(dungeon_map.player_reticle.position, dungeon_map.current_node.position)


func test_scan_reticle_repeats_through_hidden_hexes_without_moving_party() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	var party := dungeon_map.current_node
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.0)
	assert_same(dungeon_map._controller_preview_node, nodes[2])
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, DungeonScanController.REPEAT_DELAY)
	assert_same(dungeon_map._controller_preview_node, nodes[3])
	assert_same(dungeon_map.current_node, party)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.TARGETING)


func test_controller_can_scan_hidden_hex_without_changing_party_or_alert() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	var hidden: MapNode = nodes[2]
	hidden.set_state(MapNode.NodeState.HIDDEN)
	var party_node := dungeon_map.current_node
	var alert := dungeon_map.current_alert
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_selected(hidden)
	dungeon_map._sync_scan_selection(false)
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


func test_scan_selection_resynchronizes_after_modal_closes_with_neutral_input() -> void:
	InputManager._input(_joy_button())
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var selected: MapNode = setup.nodes[2]
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_selected(selected)
	dungeon_map._sync_scan_selection(false)
	var camera_position := dungeon_map.camera.position

	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	dungeon_map._process(0.016)
	assert_true(navigation.is_top_modal(terminal))
	assert_null(dungeon_map._controller_preview_node)

	terminal.queue_free()
	await get_tree().process_frame
	dungeon_map._process(0.016)

	assert_same(dungeon_map._controller_preview_node, selected)
	assert_same(dungeon_map.scan_controller.selected_node, selected)
	assert_eq(dungeon_map.camera.position, camera_position)


func test_open_modal_suppresses_active_scan_events_until_it_closes() -> void:
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
	dungeon_map.start_targeting_mode(2)
	dungeon_map.scan_controller.set_selected(selected)
	dungeon_map._sync_scan_selection(false)

	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	assert_true(navigation.is_top_modal(terminal))

	var state_before := dungeon_map.current_map_state
	var radius_before := dungeon_map.pending_scan_radius
	var active_before := dungeon_map.scan_controller.active
	var selection_before: MapNode = dungeon_map.scan_controller.selected_node
	var preview_before := dungeon_map._controller_preview_node
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

	assert_eq(dungeon_map.current_map_state, state_before)
	assert_eq(dungeon_map.pending_scan_radius, radius_before)
	assert_eq(dungeon_map.scan_controller.active, active_before)
	assert_same(dungeon_map.scan_controller.selected_node, selection_before)
	assert_same(dungeon_map._controller_preview_node, preview_before)
	assert_eq(dungeon_map.camera.zoom, zoom_before)
	assert_eq(dungeon_map.camera.position, camera_before)

	terminal.queue_free()
	await get_tree().process_frame
	dungeon_map._process(0.016)
	assert_same(dungeon_map._controller_preview_node, selected)


func test_scan_right_stick_pan_wins_over_same_frame_reticle_follow() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.scan_dead_zone_ratio = 0.1
	dungeon_map.start_targeting_mode(1)
	var before := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.RIGHT, 0.1)
	assert_gt(dungeon_map.camera.position.x, before.x)
	var manually_panned := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.1)
	assert_eq(dungeon_map.camera.position, manually_panned)


func test_scan_reticle_movement_reacquires_only_after_manual_pan_release() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.scan_dead_zone_ratio = 0.1
	dungeon_map.start_targeting_mode(1)
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.RIGHT, 0.2)
	var manually_panned := dungeon_map.camera.position
	dungeon_map._process_scan_navigation(Vector2.ZERO, Vector2.ZERO, 0.1)
	assert_eq(dungeon_map.camera.position, manually_panned)
	dungeon_map._process_scan_navigation(Vector2.LEFT, Vector2.ZERO, 0.1)
	assert_ne(dungeon_map.camera.position, manually_panned)


func test_scan_camera_approach_uses_exponential_response_without_overshoot() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.camera.zoom = Vector2(5, 5)
	dungeon_map.scan_dead_zone_ratio = 0.1
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_selected(setup.nodes[3])
	var start := dungeon_map.camera.position
	var desired: Vector2 = dungeon_map.camera_controller.desired_scanner_position(
		dungeon_map.scan_controller.selected_node.position,
		start,
		dungeon_map.get_viewport_rect().size,
		dungeon_map.camera.zoom,
	)
	var delta := 0.125
	var weight := 1.0 - exp(-8.0 * delta)
	var expected := dungeon_map._get_clamped_camera_pos(
		start.lerp(desired, weight),
		dungeon_map.camera.zoom,
	)
	dungeon_map._approach_scan_camera(delta)
	assert_almost_eq(dungeon_map.camera.position.x, expected.x, 0.001)
	assert_almost_eq(dungeon_map.camera.position.y, expected.y, 0.001)
	assert_true(dungeon_map.camera.position.distance_to(desired) < start.distance_to(desired))
	assert_true(
		dungeon_map.camera.position.distance_to(desired) > 0.0,
		"exponential response does not overshoot or snap",
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


func test_scan_movement_keeps_camera_position_ownership_during_zoom_tween() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map.max_zoom = 5.0
	dungeon_map.camera.zoom = Vector2(4.0, 4.0)
	dungeon_map.camera.position = dungeon_map.current_node.position
	dungeon_map.scan_dead_zone_ratio = 0.1
	dungeon_map.start_targeting_mode(1)
	dungeon_map.scan_controller.set_selected(setup.nodes[2])
	dungeon_map._sync_scan_selection(false)
	dungeon_map._zoom_camera(1.0)
	var selection_before: MapNode = dungeon_map.scan_controller.selected_node
	var camera_before_follow := dungeon_map.camera.position

	dungeon_map._process_scan_navigation(Vector2.RIGHT, Vector2.ZERO, 0.5)

	assert_ne(dungeon_map.scan_controller.selected_node, selection_before)
	assert_ne(dungeon_map.camera.position, camera_before_follow)
	var camera_after_follow := dungeon_map.camera.position
	await get_tree().create_timer(0.35).timeout
	assert_eq(dungeon_map.camera.position, camera_after_follow)


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


func test_modal_suppresses_active_scan_selection() -> void:
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	dungeon_map.start_targeting_mode(1)
	var selected: MapNode = dungeon_map.scan_controller.selected_node
	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	dungeon_map._process(0.1)
	assert_true(navigation.has_open_modal())
	assert_same(dungeon_map.scan_controller.selected_node, selected)
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
	assert_null(navigation.cursor._target)
	assert_eq(navigation.cursor._state, NavigationCursor.CursorState.DEFAULT)
	assert_false(navigation.cursor.visible)
	outsider.grab_focus()
	await get_tree().process_frame
	assert_null(navigation.cursor._target, "focus changes cannot assign an active adapter's world cursor")
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
	assert_null(navigation.cursor._target)
	assert_null(dungeon_map._controller_preview_node)
	assert_false(dungeon_map.player_reticle.visible)
	dungeon_map.queue_free()
	await get_tree().process_frame
	assert_null(navigation._adapter)
	assert_null(navigation.cursor._target)
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
	assert_null(navigation.cursor._target, "map preview uses its reticle, not the global cursor")

	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	dungeon_map._process(0.016)
	assert_true(navigation.is_top_modal(terminal))
	assert_null(dungeon_map._controller_preview_node)
	dungeon_map._process(0.016)
	assert_null(dungeon_map._controller_preview_node, "held input cannot navigate behind modal")
	assert_eq(get_viewport().gui_get_focus_owner(), terminal.close_button)
	assert_same(navigation.get_focus_target(), terminal.close_button)
	assert_same(navigation.cursor._target, terminal.close_button)
	assert_same(navigation._adapter, dungeon_map)

	terminal.queue_free()
	await get_tree().process_frame
	dungeon_map._process(0.016)
	assert_same(navigation._adapter, dungeon_map, "closing a modal keeps the live dungeon adapter registered")
	assert_null(navigation.cursor._target)
	assert_not_null(dungeon_map._controller_preview_node, "held input resumes after modal closes")
	assert_eq(navigation.cursor._state, NavigationCursor.CursorState.DEFAULT)
	assert_false(navigation.cursor.visible)
	assert_eq(_hint_actions(navigation), [&"confirm", &"cancel", &"camera_pan_right", &"zoom_in", &"zoom_out", &"recenter"])
	Input.action_release(&"nav_right")


func test_map_adapter_restore_clears_world_cursor_target() -> void:
	InputManager._input(_joy_button())
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	navigation.cursor.set_world_target(dungeon_map.current_node, NavigationCursor.CursorState.TARGET)
	dungeon_map.navigation_focus_restored()
	assert_null(navigation.cursor._target)
	assert_eq(navigation.cursor._state, NavigationCursor.CursorState.DEFAULT)
	assert_false(navigation.cursor.visible)


func test_map_cursor_shows_for_free_mouse_then_hides_for_keyboard_navigation() -> void:
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	InputManager._set_cursor_behavior(InputManager.CursorBehavior.SNAPPED)
	dungeon_map.select_direction(Vector2.RIGHT)
	navigation.cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_false(navigation.cursor.visible)

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(240, 180)
	motion.relative = Vector2(10, 0)
	InputManager._input(motion)
	navigation.cursor.update_position_for_behavior(InputManager.CursorBehavior.FREE, motion.position, true)
	assert_true(navigation.cursor.visible)
	assert_eq(navigation.cursor.position, motion.position)

	var navigation_key := InputEventKey.new()
	navigation_key.physical_keycode = KEY_D
	navigation_key.pressed = true
	InputManager._input(navigation_key)
	navigation.cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, motion.position, true)
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


func _hint_actions(navigation: NavigationUXLayer) -> Array[StringName]:
	var actions: Array[StringName] = []
	for index in navigation.hint_bar.get_hint_count():
		actions.append(navigation.hint_bar.get_hint(index).action)
	return actions
