extends GutTest

const DUNGEON_MAP_SCENE := preload("res://src/map/dungeon_map.tscn")
const NAVIGATION_UX_SCENE := preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const TERMINAL_SCENE := preload("res://src/map/terminal.tscn")


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


func test_controller_preview_retains_on_neutral_and_confirm_uses_validated_move() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	var cursor_start := dungeon_map.player_cursor.position

	dungeon_map.select_direction(Vector2.RIGHT)
	var preview: MapNode = dungeon_map._controller_preview_node
	assert_not_null(preview)
	assert_eq(dungeon_map.player_cursor.position, cursor_start)
	dungeon_map.select_direction(Vector2.ZERO)
	assert_same(dungeon_map._controller_preview_node, preview)
	dungeon_map.confirm_preview()
	assert_same(dungeon_map.current_node, preview)
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	assert_ne(preview, nodes[0])


func test_controller_candidates_filter_hidden_completed_unreachable_and_cancel_clears() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	nodes[2].set_state(MapNode.NodeState.COMPLETED)

	dungeon_map.select_direction(Vector2.RIGHT)
	assert_null(dungeon_map._controller_preview_node)
	nodes[2].set_state(MapNode.NodeState.REVEALED)
	dungeon_map.select_direction(Vector2.RIGHT)
	assert_same(dungeon_map._controller_preview_node, nodes[2])
	dungeon_map.cancel_preview()
	assert_null(dungeon_map._controller_preview_node)


func test_scan_selection_filters_hidden_candidates_and_cancel_cancels_scan() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var nodes: Array = setup.nodes
	nodes[2].set_state(MapNode.NodeState.HIDDEN)
	dungeon_map.start_targeting_mode(1)
	dungeon_map.select_direction(Vector2.RIGHT)
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
	dungeon_map.select_direction(Vector2.RIGHT)
	watch_signals(dungeon_map)

	dungeon_map.confirm_preview()
	assert_signal_emitted(dungeon_map, &"scan_performed")
	assert_eq(dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	assert_eq(dungeon_map.pending_scan_radius, 0)
	assert_eq(nodes[2].state, MapNode.NodeState.REVEALED)


func test_locked_state_suppresses_selection_camera_and_confirmation() -> void:
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var start_node := dungeon_map.current_node
	var start_camera := dungeon_map.camera.position
	var start_zoom := dungeon_map.camera.zoom
	dungeon_map.select_direction(Vector2.RIGHT)
	var preview: MapNode = dungeon_map._controller_preview_node
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
	assert_same(dungeon_map._controller_preview_node, preview)
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


func test_map_registers_global_adapter_targets_cursor_and_publishes_state_hints() -> void:
	InputManager._input(_joy_button())
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	var outsider := Button.new()
	add_child_autofree(outsider)
	assert_same(navigation._adapter, dungeon_map)

	dungeon_map.select_direction(Vector2.RIGHT)
	var preview: MapNode = dungeon_map._controller_preview_node
	assert_same(navigation.cursor._target, preview)
	assert_eq(navigation.cursor._state, NavigationCursor.CursorState.DEFAULT)
	assert_eq(navigation.cursor.texture.resource_path.get_file(), "pointer_c.svg")
	outsider.grab_focus()
	await get_tree().process_frame
	assert_same(navigation.cursor._target, preview, "focus changes cannot steal an active adapter's world cursor")
	assert_eq(_hint_actions(navigation), [&"confirm", &"cancel", &"camera_pan_right", &"zoom_in", &"zoom_out", &"recenter"])
	dungeon_map.current_map_state = DungeonMap.MapState.LOCKED
	dungeon_map._publish_controller_hints()
	for index in navigation.hint_bar.get_hint_count():
		assert_false(navigation.hint_bar.get_hint(index).enabled)
	dungeon_map.unlock_input()

	dungeon_map.start_targeting_mode(1)
	assert_eq(navigation.hint_bar.get_hint(0).label.text, "Scan")
	dungeon_map.cancel_preview()
	assert_same(navigation.cursor._target, dungeon_map.current_node)
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
	dungeon_map.select_direction(Vector2.RIGHT)
	var preview: MapNode = dungeon_map._controller_preview_node
	assert_same(navigation.cursor._target, preview)

	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	assert_true(navigation.is_top_modal(terminal))
	assert_eq(get_viewport().gui_get_focus_owner(), terminal.close_button)
	assert_same(navigation.get_focus_target(), terminal.close_button)
	assert_same(navigation.cursor._target, terminal.close_button)
	assert_same(navigation._adapter, dungeon_map)

	terminal.queue_free()
	await get_tree().process_frame
	assert_same(navigation._adapter, dungeon_map, "closing a modal keeps the live dungeon adapter registered")
	assert_same(navigation.cursor._target, preview)
	assert_eq(navigation.cursor._state, NavigationCursor.CursorState.DEFAULT)
	assert_eq(navigation.cursor.texture.resource_path.get_file(), "pointer_c.svg")
	assert_eq(_hint_actions(navigation), [&"confirm", &"cancel", &"camera_pan_right", &"zoom_in", &"zoom_out", &"recenter"])


func test_map_adapter_restore_clears_specialized_cursor_appearance() -> void:
	InputManager._input(_joy_button())
	var navigation := _make_navigation_ux()
	var setup := await _prepare_navigation_map()
	var dungeon_map: DungeonMap = setup.map
	navigation.cursor.set_cursor_state(NavigationCursor.CursorState.TARGET)
	navigation.cursor.clear_target()
	dungeon_map.navigation_focus_restored()
	assert_same(navigation.cursor._target, dungeon_map.current_node)
	assert_eq(navigation.cursor._state, NavigationCursor.CursorState.DEFAULT)
	assert_eq(navigation.cursor.texture.resource_path.get_file(), "pointer_c.svg")


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _joy_button() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	return event


func _hint_actions(navigation: NavigationUXLayer) -> Array[StringName]:
	var actions: Array[StringName] = []
	for index in navigation.hint_bar.get_hint_count():
		actions.append(navigation.hint_bar.get_hint(index).action)
	return actions
