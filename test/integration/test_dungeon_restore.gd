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


func test_scan_selection_filters_hidden_candidates_and_cancel_cancels_scan() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	nodes[2].set_state(MapNode.NodeState.HIDDEN)
	dungeon_map.start_targeting_mode(1)
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_not_null(dungeon_map._controller_preview_node)
	dungeon_map._reconcile_controller_navigation(Vector2.ZERO)
	assert_null(dungeon_map._controller_preview_node)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.TARGETING)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_same(dungeon_map._controller_preview_node, nodes[3])
	dungeon_map.cancel_preview()
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	assert_eq(dungeon_map.pending_scan_radius, 0)


func test_confirmed_scan_uses_existing_scan_execution_and_signal_path() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	nodes[2].set_state(MapNode.NodeState.HIDDEN)
	dungeon_map.start_targeting_mode(1)
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	assert_not_null(dungeon_map._controller_preview_node)
	dungeon_map._reconcile_controller_navigation(Vector2.ZERO)
	assert_null(dungeon_map._controller_preview_node)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.TARGETING)
	dungeon_map._reconcile_controller_navigation(Vector2.RIGHT)
	watch_signals(dungeon_map)

	dungeon_map.confirm_preview()
	assert_signal_emitted(dungeon_map, &"scan_performed")
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	assert_eq(dungeon_map.pending_scan_radius, 0)
	assert_eq(nodes[2].state, MapNode.NodeState.REVEALED)


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
	assert_null(navigation.cursor._target)
	assert_null(dungeon_map._controller_preview_node)
	assert_false(dungeon_map.player_reticle.visible)
	dungeon_map.queue_free()
	await get_tree().process_frame
	assert_null(navigation._adapter)
	assert_null(navigation.cursor._target)
	assert_eq(navigation.hint_bar.get_hint_count(), 0)


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
