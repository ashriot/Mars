extends GutTest

const UX_SCENE := preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const TITLE_SCENE := preload("res://src/core/title_screen.tscn")
const HUB_SCENE := preload("res://src/hub/hub.tscn")
const MAP_SCENE := preload("res://src/map/dungeon_map.tscn")
const TERMINAL_SCENE := preload("res://src/map/terminal.tscn")
const BATTLE_SCENE := preload("res://src/battle/battle_scene.tscn")
const HERO_CARD_SCENE := preload("res://src/battle/hero_card.tscn")
const ENEMY_CARD_SCENE := preload("res://src/battle/enemy_card.tscn")
const RESULT_SCENE := preload("res://src/map/dungeon_end_screen.tscn")
const TEST_SLOT := 987654

var _saved_slot: int
var _saved_roster: Array[HeroData] = []


func before_each() -> void:
	_saved_slot = SaveSystem.current_slot_index
	_saved_roster.assign(SaveSystem.party_roster)
	SaveSystem.current_slot_index = TEST_SLOT
	SaveSystem.party_roster.assign([load("res://data/heroes/asher/asher.tres").duplicate(true) as HeroData])
	InputManager._input(_joy_event())


func after_each() -> void:
	for tween in get_tree().get_processed_tweens():
		tween.kill()
	SaveSystem.current_slot_index = _saved_slot
	SaveSystem.party_roster.assign(_saved_roster)
	DirAccess.remove_absolute(SaveSystem._get_slot_path(TEST_SLOT))


func test_semantic_controller_path_keeps_every_screen_boundary_valid() -> void:
	var navigation := UX_SCENE.instantiate() as NavigationUXLayer
	navigation.name = "NavigationUXLayer"
	add_child_autofree(navigation)

	var title := TITLE_SCENE.instantiate() as TitleScreen
	add_child(title)
	await get_tree().process_frame
	var title_default := title.continue_button if not title.continue_button.disabled else title.start_button
	_assert_control_boundary(navigation, title_default)
	title_default.pressed.emit()
	title.free()

	var hub := HUB_SCENE.instantiate() as Hub
	add_child(hub)
	await get_tree().process_frame
	_assert_control_boundary(navigation, hub.head_out_button)
	hub.head_out_button.pressed.emit()
	hub.free()

	var dungeon := MAP_SCENE.instantiate() as DungeonMap
	add_child(dungeon)
	dungeon.map_length = 3
	dungeon.map_height = 1
	await get_tree().process_frame
	await dungeon.generate_hex_grid(false, {
		Vector2i(0, 0): MapNode.NodeType.ENTRANCE,
		Vector2i(1, 0): MapNode.NodeType.TERMINAL,
		Vector2i(2, 0): MapNode.NodeType.COMBAT,
	})
	var nodes: Array = dungeon.grid_nodes.values()
	nodes.sort_custom(func(a: MapNode, b: MapNode) -> bool: return a.position.x < b.position.x)
	for node: MapNode in nodes:
		node.set_state(MapNode.NodeState.REVEALED)
	dungeon.current_node = nodes[0]
	dungeon.current_map_state = DungeonMap.MapState.PLAYING
	dungeon.navigation_focus_restored()
	dungeon.select_direction(Vector2.RIGHT)
	_assert_adapter_boundary(navigation, dungeon, nodes[1])
	dungeon.confirm_preview()

	var terminal := TERMINAL_SCENE.instantiate()
	add_child(terminal)
	await get_tree().process_frame
	_assert_control_boundary(navigation, terminal.close_button)
	terminal.option_selected.connect(func(_choice): pass)
	terminal._on_text_link_clicked("opt_fin")
	terminal.free()
	dungeon.unlock_input()
	dungeon.current_node = nodes[1]
	dungeon.navigation_focus_restored()
	dungeon.select_direction(Vector2.RIGHT)
	_assert_adapter_boundary(navigation, dungeon, nodes[2])
	dungeon.free()

	var battle := BATTLE_SCENE.instantiate() as BattleScene
	add_child(battle)
	await get_tree().process_frame
	var hero := HERO_CARD_SCENE.instantiate() as HeroCard
	var enemy := ENEMY_CARD_SCENE.instantiate() as EnemyCard
	hero.is_defeated = false
	enemy.is_defeated = false
	enemy.is_valid_target = true
	battle.manager.hero_area.add_child(hero)
	battle.manager.enemy_area.add_child(enemy)
	battle.manager.current_actor = hero
	var first_action := battle.manager.action_bar.actions_ui.get_child(0) as ActionButton
	var action := Action.new()
	action.action_name = "Loop Smoke Action"
	first_action.action = action
	first_action.focus_cost = 0
	first_action.disabled = false
	first_action.show()
	battle.manager.action_bar.sliding = false
	battle.manager.action_bar.buttons_disabled = false
	battle.manager.current_state = BattleManager.State.PLAYER_ACTION
	watch_signals(battle.manager.action_bar)
	battle.manager.action_bar._unhandled_input(_action_event(&"action_1"))
	assert_signal_emitted_with_parameters(battle.manager.action_bar, &"action_selected", [first_action])
	battle.manager.current_state = BattleManager.State.FORCED_TARGET
	battle._controller_target = enemy
	battle.navigation_focus_restored()
	_assert_adapter_boundary(navigation, battle, enemy)
	battle.cancel_targeting()
	assert_same(navigation.cursor._target, hero, "battle cancel leaves a valid cursor region")
	battle.free()

	var result := RESULT_SCENE.instantiate() as DungeonEndScreen
	add_child(result)
	result.setup(RunManager.RunResult.DEFEAT)
	await get_tree().process_frame
	_assert_control_boundary(navigation, result.continue_button)
	result.continue_button.pressed.emit()
	assert_true(result._confirmed, "semantic result dismissal reaches the existing completion path")
	assert_true(SaveSystem._get_slot_path(TEST_SLOT).begins_with("user://test_saves/"), "test writes remain under the test save root")
	result.free()


func _assert_control_boundary(navigation: NavigationUXLayer, expected: Control) -> void:
	assert_same(get_viewport().gui_get_focus_owner(), expected)
	assert_same(navigation.get_focus_target(), expected)
	assert_same(navigation.cursor._target, expected)
	assert_true(expected.is_visible_in_tree())


func _assert_adapter_boundary(navigation: NavigationUXLayer, adapter: Object, expected: Object) -> void:
	assert_same(navigation._adapter, adapter)
	assert_same(navigation.cursor._target, expected)
	assert_true(is_instance_valid(navigation.cursor._target))


func _joy_event() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
