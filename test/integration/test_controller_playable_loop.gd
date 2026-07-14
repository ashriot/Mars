extends GutTest

const TITLE := preload("res://src/core/title_screen.tscn")
const HUB := preload("res://src/hub/hub.tscn")
const MAP := preload("res://src/map/dungeon_map.tscn")
const TERMINAL := preload("res://src/map/terminal.tscn")
const RESULT := preload("res://src/map/dungeon_end_screen.tscn")
const UX := preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const BATTLE := preload("res://src/battle/battle_scene.tscn")
const TEST_SLOT := 987654
const TEST_SAVE_ROOT := "user://test_saves/controller_playable_loop/"
const STARTING_NODE_IDS := {
	"gun": ["gun.root", "gun.fusion_ammo"],
	"snp": ["snp.root", "snp.aimed_shot"],
	"opr": ["opr.root", "opr.decoy"],
	"psi": ["psi.root", "psi.energy_barrier"],
	"kin": ["kin.root", "kin.rejuvenate"],
	"dom": ["dom.root", "dom.feedback"],
	"van": ["van.root", "van.overwatch"],
	"med": ["med.root", "med.booster_shots"],
	"stg": ["stg.root", "stg.gambit"],
}


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

	func _fade_in(_duration: float = 0.5):
		pass

	func wait(_duration: float = 0.01) -> void:
		pass

	func _flush_all_health_animations() -> void:
		pass

	func _apply_starting_passives() -> void:
		pass

	func find_and_start_next_turn():
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

	func _start_encounter(encounter: Encounter) -> void:
		var scene := BATTLE.instantiate() as BattleScene
		var packed_manager := scene.manager
		var hero_card_scene := packed_manager.hero_card_scene
		var enemy_card_scene := packed_manager.enemy_card_scene
		scene.remove_child(packed_manager)
		packed_manager.free()
		battle_manager = LoopBattleManager.new()
		battle_manager.name = "BattleManager"
		battle_manager.unique_name_in_owner = true
		battle_manager.UI = scene.get_node("UI")
		battle_manager.fx_manager = scene.get_node("FXManager")
		battle_manager.hero_area = scene.get_node("UI/Heroes/HBox")
		battle_manager.enemy_area = scene.get_node("UI/Enemies/HBox")
		battle_manager.action_bar = scene.get_node("UI/ActionBar")
		battle_manager.current_action_panel = scene.get_node("UI/CurrentAction")
		battle_manager.hero_card_scene = hero_card_scene
		battle_manager.enemy_card_scene = enemy_card_scene
		battle_manager.action_bar.battle_manager = battle_manager
		(scene.get_node("UI/TurnQueue") as TurnQueue).battle_manager = battle_manager
		battle_manager.target_confirmed.connect(func(): battle_confirmed += 1)
		scene.manager = battle_manager
		scene.add_child(battle_manager)
		battle_manager.owner = scene
		overlay_layer.add_child(scene)
		battle_scene = scene
		scene.battle_ended.connect(end_encounter)
		await (Engine.get_main_loop() as SceneTree).process_frame
		battle_manager.current_encounter = encounter
		await battle_manager.spawn_encounter()
		var hero := battle_manager.hero_area.get_child(0) as HeroCard
		battle_manager.forced_enemy = battle_manager.enemy_area.get_child(0) as EnemyCard
		battle_manager.current_actor = hero
		battle_manager.current_state = BattleManager.State.PLAYER_ACTION
		await battle_manager.action_bar.load_actions(hero)


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
var previous_storage_root := ""


func before_each() -> void:
	previous_storage_root = SaveSystem.storage_root_override
	SaveSystem.storage_root_override = TEST_SAVE_ROOT
	snapshot = _snapshot_state()
	_remove_slot(1)
	_remove_slot(TEST_SLOT)


func after_each() -> void:
	for tween in get_tree().get_processed_tweens(): tween.kill()
	_finish_state_isolation(snapshot)
	SaveSystem.storage_root_override = previous_storage_root


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
	_assert_fresh_starting_kits()
	var hub := router.current_instance as Hub
	SaveSystem.party_roster[0].current_xp = 200
	(hub.get_node("Actions/Button3") as Button).grab_focus()
	await _send(&"confirm")
	await get_tree().process_frame
	var skill_view := hub.party_menu.skill_view
	watch_signals(skill_view)
	assert_true(skill_view.focus_node("gun.anchor"))
	await _send_semantic(&"confirm")
	assert_signal_not_emitted(skill_view, "purchase_requested")
	await _send_semantic(&"nav_left")
	assert_eq(skill_view.focused_node_id, "gun.root")
	await _send_semantic(&"confirm")
	assert_signal_not_emitted(skill_view, "purchase_requested")
	await _send_semantic(&"nav_right")
	await _send_semantic(&"nav_right")
	assert_eq(skill_view.focused_node_id, "gun.fusion_ammo")
	await _send_semantic(&"confirm")
	assert_signal_not_emitted(skill_view, "purchase_requested")
	await _send_semantic(&"nav_left")
	await _send_semantic(&"nav_down")
	assert_eq(skill_view.focused_node_id, "gun.atk_1")
	await _send_semantic(&"confirm")
	assert_signal_emitted_with_parameters(skill_view, "purchase_requested", [SaveSystem.party_roster[0], "gun", "gun.atk_1"])
	assert_signal_emit_count(skill_view, "purchase_requested", 1)
	hub.party_menu._on_back_pressed()
	await get_tree().process_frame
	hub.head_out_button.grab_focus()
	_assert_focus(router.current_instance.head_out_button)
	await _send(&"confirm")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(router.current_instance is LoopManager)
	var map := router.manager.dungeon_map
	var controller_input := InputEventJoypadButton.new()
	controller_input.pressed = true
	InputManager._input(controller_input)
	Input.action_press(&"nav_right")
	await get_tree().process_frame
	assert_not_null(map._controller_preview_node)
	assert_eq(map._controller_preview_node.type, MapNode.NodeType.TERMINAL)
	await _send(&"confirm")
	Input.action_release(&"nav_right")
	await get_tree().process_frame
	await get_tree().process_frame
	var terminal := router.manager.overlay_layer.get_child(0)
	var finance: TerminalProtocolRow = terminal.get_protocol_row(2)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
	assert_same(finance.glyph.texture_normal, InputIconMap.get_glyph(InputManager.get_active_controller_type(), &"terminal_finance"))
	_assert_focus(terminal.get_protocol_row(0))
	await _send(&"terminal_finance")
	assert_eq(terminal.interaction_state, terminal.TerminalState.READY)
	await _send(&"terminal_finance")
	await get_tree().process_frame
	assert_true(router.manager.terminal_completed)
	map.navigation_focus_restored()
	Input.action_press(&"nav_right")
	await get_tree().process_frame
	assert_eq(map._controller_preview_node.type, MapNode.NodeType.COMBAT)
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER)
	await _send(&"confirm")
	Input.action_release(&"nav_right")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(router.manager.battle_scene)
	var navigation_ux := router.get_node("NavigationUXLayer") as NavigationUXLayer
	assert_same(router.manager.battle_scene._controller_target, router.manager.battle_manager.current_actor)
	assert_null(navigation_ux.cursor._target)
	var spawned_hero := router.manager.battle_manager.hero_area.get_child(0) as HeroCard
	assert_eq(spawned_hero.get_current_role().role_name, "Gunner")
	var battle_actions: Control = router.manager.battle_manager.action_bar.actions_ui
	var first_action := battle_actions.get_child(0) as ActionButton
	var second_action := battle_actions.get_child(1) as ActionButton
	assert_eq(InputManager.get_active_mode(), InputManager.InputMode.CONTROLLER, "combat inherits the global input mode before receiving battle input")
	assert_same(first_action.dynamic_glyph.texture_normal, InputIconMap.get_glyph(InputManager.get_active_controller_type(), &"action_1"))
	assert_same(second_action.dynamic_glyph.texture_normal, InputIconMap.get_glyph(InputManager.get_active_controller_type(), &"action_2"))
	assert_eq(first_action.action.resource_path, "res://data/heroes/asher/actions/double_tap.tres")
	assert_eq(second_action.action.resource_path, "res://data/heroes/asher/actions/fusion_ammo.tres")
	assert_true(first_action.visible)
	assert_true(second_action.visible)
	var previous_target := router.manager.battle_scene._controller_target
	assert_true(router.manager.battle_manager.action_bar.activate_slot(0))
	await get_tree().process_frame
	assert_eq(router.manager.battle_manager.current_state, BattleManager.State.FORCED_TARGET)
	await _send(&"nav_right")
	assert_ne(router.manager.battle_scene._controller_target, previous_target)
	assert_same(router.manager.battle_scene._controller_target, router.manager.battle_manager.forced_enemy)
	assert_same(navigation_ux.cursor._target, router.manager.battle_manager.forced_enemy)
	assert_eq(navigation_ux.cursor._state, NavigationCursor.CursorState.DEFAULT)
	await _send(&"confirm")
	await get_tree().process_frame
	assert_eq(router.manager.battle_confirmed, 1)
	var result := router.manager.overlay_layer.get_child(0) as DungeonEndScreen
	assert_not_null(result)
	_assert_focus(result.continue_button)
	await _send(&"confirm")
	await get_tree().process_frame
	assert_true(router.current_instance is Hub)
	assert_eq(SaveSystem._get_save_dir(), TEST_SAVE_ROOT)
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


func _send_semantic(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame


func _assert_focus(expected: Control) -> void:
	assert_same(get_viewport().gui_get_focus_owner(), expected)
	assert_true(expected.is_visible_in_tree())
	assert_false(expected is BaseButton and expected.disabled)


func _assert_fresh_starting_kits() -> void:
	for hero: HeroData in SaveSystem.party_roster:
		for role_id: String in hero.unlocked_role_ids:
			var progress: HeroRoleProgress = hero.role_progress.get(role_id)
			assert_not_null(progress, "%s/%s" % [hero.hero_id, role_id])
			assert_eq(progress.owned_node_ids, STARTING_NODE_IDS[role_id], "%s/%s exact starting IDs" % [hero.hero_id, role_id])
			assert_eq(progress.xp_paid_by_node, {
				STARTING_NODE_IDS[role_id][0]: 0,
				STARTING_NODE_IDS[role_id][1]: 0,
			}, "%s/%s zero starting prices" % [hero.hero_id, role_id])


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
		DirAccess.make_dir_recursive_absolute(SaveSystem._get_save_dir())
		var file := FileAccess.open(SaveSystem._get_slot_path(slot), FileAccess.WRITE)
		assert_not_null(file)
		if file:
			file.store_buffer(state.bytes)


func _write_slot_bytes(slot: int, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem._get_save_dir())
	var file := FileAccess.open(SaveSystem._get_slot_path(slot), FileAccess.WRITE)
	assert_not_null(file)
	if file:
		file.store_buffer(bytes)


func _remove_slot(slot: int) -> void:
	var path := SaveSystem._get_slot_path(slot)
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
