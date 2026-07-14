extends GutTest


class FakeDungeonMap extends DungeonMap:
	func _ready() -> void:
		pass


class BattleDungeonMap extends FakeDungeonMap:
	var exit_visuals_count := 0
	var refresh_count := 0

	func exit_battle_visuals(_duration: float = 1.0) -> void:
		exit_visuals_count += 1

	func refresh_team_status() -> void:
		refresh_count += 1


class FloatingTextDouble extends FloatingText:
	func setup(
		_pos: Vector2,
		_text: String,
		_texture: Texture2D = null,
		_color: Color = Color.WHITE,
		_scale_mult: float = 1.0
	) -> void:
		pass


class InteractionManagerDouble extends GameManager:
	var completed_count := 0
	var canceled_count := 0
	var cleared_count := 0
	var encounter_count := 0
	var last_error := ""

	func _ready() -> void:
		pass

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


class RealCancellationManager extends GameManager:
	func _ready() -> void:
		pass


class EndingManagerDouble extends InteractionManagerDouble:
	var presented_results: Array[RunManager.RunResult] = []

	func _present_end_screen(result: RunManager.RunResult) -> void:
		presented_results.append(result)


class ExtractionLifecycleManager extends GameManager:
	func _ready() -> void:
		pass


class EndScreenDouble extends DungeonEndScreen:
	var commit_count := 0

	func _commit_rewards() -> void:
		commit_count += 1


class AsyncEncounterManager extends GameManager:
	var completed_count := 0
	var presented_results: Array[RunManager.RunResult] = []

	func _ready() -> void:
		pass

	func _complete_current_interaction() -> void:
		await (Engine.get_main_loop() as SceneTree).process_frame
		completed_count += 1

	func _present_end_screen(result: RunManager.RunResult) -> void:
		presented_results.append(result)


func _manager() -> InteractionManagerDouble:
	var manager := InteractionManagerDouble.new()
	manager.dungeon_map = FakeDungeonMap.new()
	manager.overlay_layer = Node.new()
	manager.add_child(manager.dungeon_map)
	manager.add_child(manager.overlay_layer)
	return manager


func _real_cancellation_manager() -> RealCancellationManager:
	var manager := RealCancellationManager.new()
	manager.dungeon_map = FakeDungeonMap.new()
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


func test_error_real_cancellation_unlocks_map_and_clears_overlay() -> void:
	var manager := _real_cancellation_manager()
	manager.dungeon_map.current_map_state = DungeonMap.MapState.LOCKED
	var transient := Node.new()
	manager.overlay_layer.add_child(transient)

	await manager._finish_interaction(GameManager.InteractionOutcome.ERROR)

	assert_eq(manager.dungeon_map.current_map_state, DungeonMap.MapState.PLAYING)
	assert_true(transient.is_queued_for_deletion())
	await get_tree().process_frame
	assert_false(is_instance_valid(transient))
	manager.free()


func test_error_cancels_once_while_run_ended_has_no_interaction_cleanup() -> void:
	var manager := _manager()

	await manager._finish_interaction(GameManager.InteractionOutcome.ERROR)
	assert_eq(manager.canceled_count, 1)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.cleared_count, 0)

	await manager._finish_interaction(GameManager.InteractionOutcome.RUN_ENDED)
	assert_eq(manager.canceled_count, 1)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.cleared_count, 0)
	manager.free()


func test_missing_terminal_payload_reports_context_and_remains_retryable() -> void:
	var manager := _manager()
	var node := _node(MapNode.NodeType.TERMINAL)

	manager._on_map_interaction_requested(node)

	assert_push_error("terminal payload")
	assert_string_contains(manager.last_error, "(3, 4)")
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 1)
	node.free()
	manager.free()


func test_malformed_terminal_payload_reports_value_and_remains_retryable() -> void:
	var manager := _manager()
	var node := _node(MapNode.NodeType.TERMINAL)
	manager.dungeon_map.terminal_memory[node.grid_coords] = {"facility_name": 42}

	manager._on_map_interaction_requested(node)

	assert_push_error("terminal payload")
	assert_string_contains(manager.last_error, "facility_name")
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 1)
	node.free()
	manager.free()


func test_malformed_encounter_payload_reports_context_and_remains_retryable() -> void:
	var manager := _manager()
	var node := _node(MapNode.NodeType.COMBAT)
	manager.dungeon_map.encounter_memory[node.grid_coords] = ["attack_drones_1", false]

	manager._on_map_interaction_requested(node)

	assert_push_error("encounter payload")
	assert_string_contains(manager.last_error, "(3, 4)")
	assert_eq(manager.encounter_count, 0)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 1)
	node.free()
	manager.free()


func test_unknown_encounter_reports_id_and_remains_retryable() -> void:
	var manager := _manager()
	var node := _node(MapNode.NodeType.COMBAT)
	manager.dungeon_map.encounter_memory[node.grid_coords] = ["definitely_missing", false, false]

	manager._on_map_interaction_requested(node)

	assert_push_error("definitely_missing")
	assert_string_contains(manager.last_error, "(3, 4)")
	assert_eq(manager.encounter_count, 0)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 1)
	node.free()
	manager.free()


func test_valid_encounter_payload_starts_battle_without_completing_node() -> void:
	var manager := _manager()
	var node := _node(MapNode.NodeType.COMBAT)
	manager.dungeon_map.encounter_memory[node.grid_coords] = ["attack_drones_1", false, false]

	manager._on_map_interaction_requested(node)

	assert_eq(manager.encounter_count, 1)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 0)
	node.free()
	manager.free()


func test_missing_and_malformed_reward_payloads_remain_retryable() -> void:
	for payload in [null, {"type": LootManager.LootType.BITS}]:
		var manager := _manager()
		var node := _node(MapNode.NodeType.REWARD)
		if payload != null:
			manager.dungeon_map.reward_memory[node.grid_coords] = payload

		manager._on_map_interaction_requested(node)

		assert_push_error("reward payload")
		assert_string_contains(manager.last_error, "(3, 4)")
		assert_eq(manager.completed_count, 0)
		assert_eq(manager.canceled_count, 1)
		node.free()
		manager.free()


func test_invalid_reward_resources_remain_retryable_without_granting() -> void:
	var original_inventory := RunManager.run_inventory.duplicate(true)
	var original_mods := RunManager.run_mods_loot.duplicate()
	for payload in [
		{"type": LootManager.LootType.MATERIAL, "id": "", "amount": 2},
		{"type": LootManager.LootType.MATERIAL, "id": "missing_item", "amount": 2},
		{"type": LootManager.LootType.MATERIAL, "id": "pistol", "amount": 2},
		{"type": LootManager.LootType.MATERIAL, "id": "comp_weap_1_common", "amount": 2},
		{"type": LootManager.LootType.COMPONENT, "id": "mat_weap_1", "amount": 2},
		{"type": LootManager.LootType.EQUIPMENT, "id": "health_booster"},
		{"type": LootManager.LootType.MOD, "id": "pistol", "tier": 2},
	]:
		var manager := _manager()
		var node := _node(MapNode.NodeType.REWARD)
		manager.dungeon_map.reward_memory[node.grid_coords] = payload

		manager._on_map_interaction_requested(node)

		assert_push_error("reward payload")
		if payload.id.is_empty():
			assert_string_contains(manager.last_error, '"id": ""')
		else:
			assert_string_contains(manager.last_error, str(payload.id))
		assert_eq(RunManager.run_inventory, original_inventory)
		assert_eq(RunManager.run_mods_loot, original_mods)
		assert_eq(manager.completed_count, 0)
		assert_eq(manager.canceled_count, 1)
		node.free()
		manager.free()
	RunManager.run_inventory = original_inventory
	RunManager.run_mods_loot = original_mods


func test_valid_terminal_payload_instantiates_and_connects_terminal_without_finishing() -> void:
	var manager := _manager()
	manager.remove_child(manager.overlay_layer)
	add_child(manager.overlay_layer)
	manager.terminal_scene_packed = load("res://src/map/terminal.tscn")
	var node := _node(MapNode.NodeType.TERMINAL)
	manager.dungeon_map.terminal_memory[node.grid_coords] = _terminal_payload()

	manager._on_map_interaction_requested(node)

	assert_eq(manager.overlay_layer.get_child_count(), 1)
	var terminal := manager.overlay_layer.get_child(0)
	assert_eq(terminal.get_script(), load("res://src/map/terminal.gd"))
	assert_eq(terminal.interaction_state, terminal.TerminalState.TYPING)
	assert_eq(terminal.get_protocol_row(0).get_choice_id(), &"opt_sec")
	assert_eq(terminal.option_selected.get_connections().size(), 1)
	assert_true(terminal.closed.is_connected(manager._on_terminal_closed))
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 0)
	node.free()
	manager.overlay_layer.free()
	manager.free()
	await get_tree().process_frame


func test_valid_bits_reward_grants_once_and_completes_once() -> void:
	var original_bits := RunManager.run_bits
	var manager := _manager()
	manager.floating_text_scene = _floating_text_scene()
	var node := _node(MapNode.NodeType.REWARD)
	manager.dungeon_map.reward_memory[node.grid_coords] = {
		"type": LootManager.LootType.BITS,
		"amount": 17,
	}

	manager._on_map_interaction_requested(node)

	assert_eq(RunManager.run_bits, original_bits + 17)
	assert_eq(manager.completed_count, 1)
	assert_eq(manager.canceled_count, 0)
	RunManager.run_bits = original_bits
	for player in AudioManager._sfx_players:
		player.stop()
	node.free()
	manager.free()


func test_event_and_unknown_preserve_generic_completion_behavior() -> void:
	for type in [MapNode.NodeType.EVENT, MapNode.NodeType.UNKNOWN]:
		var manager := _manager()
		var node := _node(type)

		manager._on_map_interaction_requested(node)

		assert_eq(manager.completed_count, 1)
		assert_eq(manager.canceled_count, 0)
		node.free()
		manager.free()


func test_terminal_close_cancels_and_scan_success_completes() -> void:
	var manager := _manager()

	manager._on_terminal_closed()
	assert_eq(manager.canceled_count, 1)
	assert_eq(manager.completed_count, 0)

	manager._on_scan_success()
	manager._on_scan_success()
	assert_eq(manager.canceled_count, 1)
	assert_eq(manager.completed_count, 1)
	manager.free()


func test_scan_cancel_reopens_current_terminal_without_completion() -> void:
	var manager := _manager()
	manager.remove_child(manager.overlay_layer)
	add_child(manager.overlay_layer)
	manager.terminal_scene_packed = load("res://src/map/terminal.tscn")
	var node := _node(MapNode.NodeType.TERMINAL)
	manager.dungeon_map.current_node = node
	manager.dungeon_map.terminal_memory[node.grid_coords] = _terminal_payload()
	manager.dungeon_map.scan_performed.connect(manager._on_scan_success)

	manager._on_scan_canceled()
	manager._on_scan_canceled()

	assert_false(manager.dungeon_map.scan_performed.is_connected(manager._on_scan_success))
	assert_eq(manager.overlay_layer.get_child_count(), 1)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 0)
	node.free()
	manager.overlay_layer.free()
	manager.free()
	await get_tree().process_frame


func test_finance_terminal_choice_grants_once_and_completes_once() -> void:
	var original_bits := RunManager.run_bits
	var manager := _manager()

	manager._on_terminal_choice("opt_fin", _terminal_payload())

	assert_eq(RunManager.run_bits, original_bits + 12)
	assert_eq(manager.completed_count, 1)
	assert_eq(manager.canceled_count, 0)
	RunManager.run_bits = original_bits
	manager.free()


func test_terminal_extraction_presents_retreat_and_only_routes_run_ended() -> void:
	var manager := EndingManagerDouble.new()
	manager.dungeon_map = FakeDungeonMap.new()
	manager.overlay_layer = Node.new()
	manager.add_child(manager.dungeon_map)
	manager.add_child(manager.overlay_layer)
	var node := _node(MapNode.NodeType.TERMINAL)
	manager.dungeon_map.current_node = node

	manager._on_terminal_choice("opt_extract", _terminal_payload())

	assert_eq(manager.presented_results, [RunManager.RunResult.RETREAT])
	assert_true(manager._run_end_started)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 0)
	assert_eq(manager.cleared_count, 1)
	node.free()
	manager.free()


func test_real_terminal_extraction_close_does_not_clear_end_screen() -> void:
	var manager := ExtractionLifecycleManager.new()
	manager.dungeon_map = FakeDungeonMap.new()
	manager.overlay_layer = Node.new()
	manager.add_child(manager.dungeon_map)
	add_child(manager.overlay_layer)
	manager.terminal_scene_packed = load("res://src/map/terminal.tscn")
	manager.dungeon_end_screen_scene = load("res://src/map/dungeon_end_screen.tscn")
	var node := _node(MapNode.NodeType.TERMINAL)
	manager.dungeon_map.current_node = node
	manager.dungeon_map.terminal_memory[node.grid_coords] = _terminal_payload()

	manager._on_map_interaction_requested(node)
	var terminal := manager.overlay_layer.get_child(0)
	terminal.finish_typing()
	assert_true(terminal.handle_semantic_action(&"terminal_extract"))
	assert_true(terminal.handle_semantic_action(&"confirm"))
	await get_tree().create_timer(0.35).timeout

	assert_true(manager._run_end_started)
	assert_eq(manager.overlay_layer.get_child_count(), 1)
	assert_true(manager.overlay_layer.get_child(0) is DungeonEndScreen)
	node.free()
	manager.overlay_layer.free()
	manager.free()
	await get_tree().process_frame


func test_battle_defeat_presents_defeat_and_only_routes_run_ended() -> void:
	var manager := EndingManagerDouble.new()
	var dungeon_map := BattleDungeonMap.new()
	manager.dungeon_map = dungeon_map
	manager.overlay_layer = Node.new()
	manager.add_child(manager.dungeon_map)
	manager.add_child(manager.overlay_layer)

	manager.end_encounter(false)

	assert_eq(dungeon_map.exit_visuals_count, 1)
	assert_eq(dungeon_map.refresh_count, 1)
	assert_eq(manager.presented_results, [RunManager.RunResult.DEFEAT])
	assert_true(manager._run_end_started)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 0)
	assert_eq(manager.cleared_count, 1)
	manager.free()


func test_begin_run_end_is_guarded_clears_once_and_keeps_map_locked() -> void:
	var manager := EndingManagerDouble.new()
	manager.dungeon_map = FakeDungeonMap.new()
	manager.overlay_layer = Node.new()
	manager.add_child(manager.dungeon_map)
	manager.add_child(manager.overlay_layer)
	manager.dungeon_map.current_map_state = DungeonMap.MapState.PLAYING

	manager._begin_run_end(RunManager.RunResult.SUCCESS)
	manager._begin_run_end(RunManager.RunResult.DEFEAT)

	assert_eq(manager.presented_results, [RunManager.RunResult.SUCCESS])
	assert_eq(manager.cleared_count, 1)
	assert_eq(manager.dungeon_map.current_map_state, DungeonMap.MapState.LOCKED)
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 0)
	manager.free()


func test_entrance_and_exit_have_explicit_results() -> void:
	for case in [
		[MapNode.NodeType.ENTRANCE, RunManager.RunResult.RETREAT],
		[MapNode.NodeType.EXIT, RunManager.RunResult.SUCCESS],
	]:
		var manager := EndingManagerDouble.new()
		manager.dungeon_map = FakeDungeonMap.new()
		manager.overlay_layer = Node.new()
		manager.add_child(manager.dungeon_map)
		manager.add_child(manager.overlay_layer)
		var node := _node(case[0])

		manager._on_map_interaction_requested(node)

		assert_eq(manager.presented_results, [case[1]])
		assert_eq(manager.completed_count, 0)
		assert_eq(manager.canceled_count, 0)
		node.free()
		manager.free()


func test_duplicate_terminal_extraction_presents_one_retreat() -> void:
	var manager := EndingManagerDouble.new()
	manager.dungeon_map = FakeDungeonMap.new()
	manager.overlay_layer = Node.new()
	manager.add_child(manager.dungeon_map)
	manager.add_child(manager.overlay_layer)

	manager._on_terminal_choice("opt_extract", _terminal_payload())
	manager._on_terminal_choice("opt_extract", _terminal_payload())
	manager._on_terminal_closed()

	assert_eq(manager.presented_results, [RunManager.RunResult.RETREAT])
	assert_eq(manager.completed_count, 0)
	assert_eq(manager.canceled_count, 0)
	manager.free()


func test_battle_result_distinguishes_normal_boss_and_defeat() -> void:
	var manager := EndingManagerDouble.new()
	manager.dungeon_map = BattleDungeonMap.new()
	manager.overlay_layer = Node.new()
	manager.add_child(manager.dungeon_map)
	manager.add_child(manager.overlay_layer)
	var normal := Encounter.new()
	var boss := Encounter.new()
	boss.is_boss = true

	manager.current_encounter = normal
	assert_eq(manager._result_for_battle_end(false), RunManager.RunResult.DEFEAT)
	assert_eq(manager._result_for_battle_end(true), -1)
	manager.end_encounter(true)
	assert_eq(manager.presented_results, [])
	assert_eq(manager.completed_count, 1)

	manager.current_encounter = boss
	manager._encounter_resolution_started = false
	assert_eq(manager._result_for_battle_end(true), RunManager.RunResult.SUCCESS)
	manager.end_encounter(true)
	assert_eq(manager.presented_results, [RunManager.RunResult.SUCCESS])
	assert_eq(manager.completed_count, 1)
	for player in [AudioManager._music_player_1, AudioManager._music_player_2]:
		player.stop()
		player.stream = null
	AudioManager._current_music_player = null
	AudioManager._current_track_key = ""
	manager.free()


func test_duplicate_normal_battle_end_is_ignored_while_completion_awaits() -> void:
	var manager := AsyncEncounterManager.new()
	var dungeon_map := BattleDungeonMap.new()
	manager.dungeon_map = dungeon_map
	manager.overlay_layer = Node.new()
	manager.add_child(dungeon_map)
	manager.add_child(manager.overlay_layer)
	manager.current_encounter = Encounter.new()

	manager.end_encounter(true)
	manager.end_encounter(true)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(dungeon_map.exit_visuals_count, 1)
	assert_eq(manager.completed_count, 1)
	assert_eq(dungeon_map.refresh_count, 1)
	assert_eq(manager.presented_results, [])
	for player in [AudioManager._music_player_1, AudioManager._music_player_2]:
		player.stop()
		player.stream = null
	AudioManager._current_music_player = null
	AudioManager._current_track_key = ""
	manager.free()


func test_real_result_screen_survives_cleanup_and_exits_once() -> void:
	var manager := ExtractionLifecycleManager.new()
	manager.dungeon_map = FakeDungeonMap.new()
	manager.overlay_layer = Node.new()
	manager.add_child(manager.dungeon_map)
	add_child(manager.overlay_layer)
	manager.dungeon_end_screen_scene = load("res://src/map/dungeon_end_screen.tscn")
	var transient := Node.new()
	manager.overlay_layer.add_child(transient)
	var exit_count := [0]
	manager.dungeon_exited.connect(func(_success: bool): exit_count[0] += 1)

	manager._begin_run_end(RunManager.RunResult.RETREAT)
	await get_tree().process_frame

	assert_false(is_instance_valid(transient))
	assert_eq(manager.overlay_layer.get_child_count(), 1)
	var screen := manager.overlay_layer.get_child(0) as DungeonEndScreen
	assert_not_null(screen)
	screen.finished.emit()
	screen.finished.emit()
	assert_eq(exit_count[0], 1)
	manager.overlay_layer.free()
	manager.free()
	await get_tree().process_frame


func test_end_screen_continue_commits_and_finishes_once() -> void:
	var screen := EndScreenDouble.new()
	var button := Button.new()
	screen.add_child(button)
	screen.continue_button = button
	var finished_count := [0]
	screen.finished.connect(func(): finished_count[0] += 1)

	screen._on_continue_pressed()
	screen._on_continue_pressed()

	assert_eq(screen.commit_count, 1)
	assert_eq(finished_count[0], 1)
	assert_true(button.disabled)
	screen.free()


func _terminal_payload() -> Dictionary:
	return {
		"facility_name": "ALPHA",
		"session_id": "session",
		"terminal_index": 0,
		"bits": 12,
		"alert": 5.0,
		"upgrade_key": "finance",
	}


func _floating_text_scene() -> PackedScene:
	var scene := PackedScene.new()
	var floating_text := FloatingTextDouble.new()
	assert_eq(scene.pack(floating_text), OK)
	floating_text.free()
	return scene
