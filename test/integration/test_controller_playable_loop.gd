extends GutTest

const TITLE := preload("res://src/core/title_screen.tscn")
const HUB := preload("res://src/hub/hub.tscn")
const MAP := preload("res://src/map/dungeon_map.tscn")
const TERMINAL := preload("res://src/map/terminal.tscn")
const RESULT := preload("res://src/map/dungeon_end_screen.tscn")
const UX := preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const ACTION_BUTTON := preload("res://src/battle/action_button.tscn")
const HERO_CARD := preload("res://src/battle/hero_card.tscn")
const ENEMY_CARD := preload("res://src/battle/enemy_card.tscn")
const TEST_ACTION := preload("res://data/heroes/asher/actions/double_tap.tres")
const TEST_SLOT := 987654


class LoopActionBar extends ActionBar:
	func _ready() -> void:
		pass


class LoopBattleManager extends BattleManager:
	signal target_confirmed
	var confirmed_targets := 0
	var forced_enemy: EnemyCard

	func _ready() -> void:
		action_bar.action_selected.connect(_on_action_button_pressed)

	func _on_action_button_pressed(button: ActionButton):
		current_action = button.action
		current_state = State.FORCED_TARGET
		forced_enemy.is_valid_target = true

	func _on_enemy_clicked(enemy: EnemyCard):
		confirmed_targets += 1
		assert(enemy == forced_enemy)
		target_confirmed.emit()
		battle_ended.emit(false)

	func _clear_all_targeting_ui():
		pass


class LoopManager extends GameManager:
	var terminal_completed := false
	var battle_manager: LoopBattleManager
	var battle_confirmed := 0

	func _ready() -> void:
		pass

	func _complete_current_interaction() -> void:
		terminal_completed = true
		_clear_transient_overlay()
		dungeon_map.unlock_input()

	func _start_encounter(_encounter: Encounter) -> void:
		var scene := BattleScene.new()
		battle_manager = LoopBattleManager.new()
		battle_manager.target_confirmed.connect(func(): battle_confirmed += 1)
		var bar := LoopActionBar.new()
		bar.actions_ui = Control.new()
		bar.actions_ui.name = "Actions"
		bar.add_child(bar.actions_ui)
		for index in 4:
			var button := ACTION_BUTTON.instantiate() as ActionButton
			button.button = button.get_node("Button")
			button.action = TEST_ACTION
			button.visible = index == 0
			button.button.disabled = index != 0
			bar.actions_ui.add_child(button)
		var passive := Panel.new(); passive.name = "Passive"; bar.actions_ui.add_child(passive)
		var shift_panel := Panel.new(); shift_panel.name = "ShiftAction"; bar.actions_ui.add_child(shift_panel)
		for side in ["LeftShift", "RightShift"]:
			var shift := Control.new(); shift.name = side
			var shift_button := Button.new(); shift_button.name = "Button"; shift.add_child(shift_button); bar.add_child(shift)
		bar.battle_manager = battle_manager
		bar.buttons_disabled = false
		bar.sliding = false
		battle_manager.action_bar = bar
		var hero := HERO_CARD.instantiate() as HeroCard
		var enemy := ENEMY_CARD.instantiate() as EnemyCard
		hero.is_defeated = false
		enemy.is_defeated = false
		battle_manager.forced_enemy = enemy
		battle_manager.current_actor = hero
		battle_manager.current_state = BattleManager.State.PLAYER_ACTION
		battle_manager.hero_area = Control.new()
		battle_manager.enemy_area = Control.new()
		battle_manager.hero_area.add_child(hero)
		battle_manager.enemy_area.add_child(enemy)
		battle_manager.add_child(battle_manager.hero_area)
		battle_manager.add_child(battle_manager.enemy_area)
		battle_manager.add_child(bar)
		scene.manager = battle_manager
		scene.add_child(battle_manager)
		overlay_layer.add_child(scene)
		battle_scene = scene
		scene.battle_ended.connect(end_encounter)


class LoopRouter extends Main:
	var manager: LoopManager

	func _ready() -> void:
		pass

	func _fade_out() -> void:
		pass

	func _fade_in() -> void:
		pass

	func _switch_scene(packed_scene: PackedScene, setup_func: Callable = Callable()):
		_change_content(packed_scene, menu_layer)
		if setup_func.is_valid(): setup_func.call()

	func start_dungeon_run():
		RunManager.prepare_fresh_run()
		if current_instance:
			current_instance.queue_free()
			current_instance = null
			await (Engine.get_main_loop() as SceneTree).process_frame
		manager = LoopManager.new()
		current_instance = manager
		var map := MAP.instantiate() as DungeonMap
		map.name = "DungeonMap"
		var overlay := CanvasLayer.new()
		overlay.name = "OverlayLayer"
		map.add_child(overlay)
		manager.add_child(map)
		world_layer.add_child(manager)
		manager.dungeon_map = map
		manager.overlay_layer = overlay
		map.map_length = 3
		map.map_height = 1
		await map.generate_hex_grid(false, {
			Vector2i(0, 0): MapNode.NodeType.ENTRANCE,
			Vector2i(1, 0): MapNode.NodeType.TERMINAL,
			Vector2i(2, 0): MapNode.NodeType.COMBAT,
		})
		var nodes: Array = map.grid_nodes.values()
		nodes.sort_custom(func(a: MapNode, b: MapNode): return a.position.x < b.position.x)
		for node: MapNode in nodes: node.set_state(MapNode.NodeState.REVEALED)
		map.current_node = nodes[0]
		map.current_map_state = DungeonMap.MapState.PLAYING
		map.terminal_memory[nodes[1].grid_coords] = _terminal_payload()
		map.encounter_memory[nodes[2].grid_coords] = ["attack_drones_1", false, false]
		map.interaction_requested.connect(manager._on_map_interaction_requested)
		manager.terminal_scene_packed = TERMINAL
		manager.dungeon_end_screen_scene = RESULT
		manager.dungeon_exited.connect(return_to_hub_with_rewards)
		map.navigation_focus_restored()

	func _terminal_payload() -> Dictionary:
		return {"facility_name":"LOOP", "session_id":"fixed", "terminal_index":0, "bits":10, "alert":5.0, "upgrade_key":"finance"}


var snapshot := {}


func before_each() -> void:
	snapshot = _snapshot_state()
	_remove_slot(1)
	_remove_slot(TEST_SLOT)


func after_each() -> void:
	for tween in get_tree().get_processed_tweens(): tween.kill()
	_finish_state_isolation(snapshot)


func test_teardown_preserves_preexisting_slot_one_and_sentinel_bytes() -> void:
	var slot_one_bytes := "slot-one-before-loop".to_utf8_buffer()
	var sentinel_bytes := "dedicated-sentinel-before-loop".to_utf8_buffer()
	_write_slot_bytes(1, slot_one_bytes)
	_write_slot_bytes(TEST_SLOT, sentinel_bytes)
	var seeded := _snapshot_state()
	_write_slot_bytes(1, "mutated-one".to_utf8_buffer())
	_write_slot_bytes(TEST_SLOT, "mutated-sentinel".to_utf8_buffer())
	_finish_state_isolation(seeded)
	assert_eq(FileAccess.get_file_as_bytes(SaveSystem._get_slot_path(1)), slot_one_bytes)
	assert_eq(FileAccess.get_file_as_bytes(SaveSystem._get_slot_path(TEST_SLOT)), sentinel_bytes)


func test_controller_events_route_the_complete_playable_loop() -> void:
	var router := _router()
	add_child_autofree(router)
	await router.load_title_screen()
	await get_tree().process_frame
	assert_true(router.current_instance is TitleScreen)
	_assert_focus(router.current_instance.start_button)
	await _send(&"confirm")
	await get_tree().process_frame
	assert_true(router.current_instance is Hub)
	_assert_focus(router.current_instance.head_out_button)
	await _send(&"confirm")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(router.current_instance is LoopManager)
	var map := router.manager.dungeon_map
	await _send(&"nav_right")
	assert_not_null(map._controller_preview_node)
	assert_eq(map._controller_preview_node.type, MapNode.NodeType.TERMINAL)
	await _send(&"confirm")
	await get_tree().process_frame
	var terminal := router.manager.overlay_layer.get_child(0)
	assert_eq(terminal.get_script(), load("res://src/map/terminal.gd"))
	_assert_focus(terminal.close_button)
	await _send(&"action_4")
	await get_tree().process_frame
	assert_true(router.manager.terminal_completed)
	map.navigation_focus_restored()
	await _send(&"nav_right")
	assert_eq(map._controller_preview_node.type, MapNode.NodeType.COMBAT)
	await _send(&"confirm")
	await get_tree().process_frame
	assert_not_null(router.manager.battle_scene)
	await _send(&"action_1")
	await get_tree().process_frame
	assert_eq(router.manager.battle_manager.current_state, BattleManager.State.FORCED_TARGET)
	await _send(&"confirm")
	await get_tree().process_frame
	assert_eq(router.manager.battle_confirmed, 1)
	var result := router.manager.overlay_layer.get_child(0) as DungeonEndScreen
	assert_not_null(result)
	_assert_focus(result.continue_button)
	await _send(&"confirm")
	await get_tree().process_frame
	assert_true(router.current_instance is Hub)
	assert_eq(SaveSystem._get_save_dir(), "user://test_saves/")
	assert_false(FileAccess.file_exists(SaveSystem._get_slot_path(TEST_SLOT)))


func _router() -> LoopRouter:
	var router := LoopRouter.new()
	router.title_scene = TITLE
	router.hub_scene = HUB
	var world := Node2D.new()
	world.name = "WorldLayer"
	var menu := CanvasLayer.new()
	menu.name = "MenuLayer"
	var transition := CanvasLayer.new()
	transition.name = "TransitionLayer"
	var fader := ColorRect.new()
	fader.name = "Fader"
	transition.add_child(fader)
	router.add_child(world)
	router.add_child(menu)
	router.add_child(transition)
	var ux := UX.instantiate()
	ux.name = "NavigationUXLayer"
	router.add_child(ux)
	return router


func _send(action: StringName) -> void:
	if action in [&"nav_left", &"nav_right", &"nav_up", &"nav_down"]:
		Input.action_press(action)
		await get_tree().process_frame
		Input.action_release(action)
		await get_tree().process_frame
		return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame


func _assert_focus(expected: Control) -> void:
	assert_same(get_viewport().gui_get_focus_owner(), expected)
	assert_true(expected.is_visible_in_tree())
	assert_false(expected is BaseButton and expected.disabled)


func _snapshot_state() -> Dictionary:
	return {
		"slot": SaveSystem.current_slot_index, "bits": SaveSystem.bits, "data": SaveSystem.data.duplicate(true),
		"roster": SaveSystem.party_roster.duplicate(), "inventory": SaveSystem.inventory.duplicate(true),
		"equipment": SaveSystem.inventory_equipment.duplicate(), "mods": SaveSystem.inventory_mods.duplicate(),
		"lifetime": SaveSystem.total_lifetime_xp, "issues": SaveSystem.last_load_issues.duplicate(),
		"run_active": RunManager.is_run_active, "active_map": RunManager.active_dungeon_map,
		"profile": RunManager.dungeon_profile, "tier": RunManager.current_dungeon_tier, "seed": RunManager.current_run_seed,
		"run_bits": RunManager.run_bits, "run_xp": RunManager.run_xp, "run_inventory": RunManager.run_inventory.duplicate(true),
		"run_equipment": RunManager.run_equipment_loot.duplicate(), "run_mods": RunManager.run_mods_loot.duplicate(),
		"committed": RunManager._rewards_committed, "slot1": _file_snapshot(1), "test_slot": _file_snapshot(TEST_SLOT),
	}


func _restore_state(s: Dictionary) -> void:
	SaveSystem.current_slot_index=s.slot; SaveSystem.bits=s.bits; SaveSystem.data=s.data; SaveSystem.party_roster.assign(s.roster)
	SaveSystem.inventory=s.inventory; SaveSystem.inventory_equipment.assign(s.equipment); SaveSystem.inventory_mods.assign(s.mods)
	SaveSystem.total_lifetime_xp=s.lifetime; SaveSystem.last_load_issues.assign(s.issues)
	RunManager.is_run_active=s.run_active; RunManager.active_dungeon_map=s.active_map; RunManager.dungeon_profile=s.profile
	RunManager.current_dungeon_tier=s.tier; RunManager.current_run_seed=s.seed; RunManager.run_bits=s.run_bits; RunManager.run_xp=s.run_xp
	RunManager.run_inventory=s.run_inventory; RunManager.run_equipment_loot.assign(s.run_equipment); RunManager.run_mods_loot.assign(s.run_mods); RunManager._rewards_committed=s.committed
	_restore_file(1, s.slot1); _restore_file(TEST_SLOT, s.test_slot)


func _finish_state_isolation(state: Dictionary) -> void:
	_restore_state(state)


func _file_snapshot(slot: int) -> Dictionary:
	var path := SaveSystem._get_slot_path(slot)
	return {"exists":FileAccess.file_exists(path), "bytes":FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}


func _restore_file(slot: int, state: Dictionary) -> void:
	_remove_slot(slot)
	if state.exists:
		var file := FileAccess.open(SaveSystem._get_slot_path(slot), FileAccess.WRITE)
		file.store_buffer(state.bytes)


func _write_slot_bytes(slot: int, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(SaveSystem._get_slot_path(slot), FileAccess.WRITE)
	file.store_buffer(bytes)


func _remove_slot(slot: int) -> void:
	var path := SaveSystem._get_slot_path(slot)
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
