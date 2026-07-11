extends GutTest

const ActionButtonScene := preload("res://src/battle/action_button.tscn")


class TrackingBattleScene extends BattleScene:
	var cursor_update_count := 0

	func _update_cursor() -> void:
		cursor_update_count += 1

class TrackingBattleManager extends BattleManager:
	var selected_hero: HeroCard
	var selected_enemy: EnemyCard
	var shift_direction := ""
	var clear_count := 0
	var enemy_hover_count := 0
	var enemy_unhover_count := 0

	func _on_hero_clicked(hero: HeroCard):
		selected_hero = hero

	func _on_enemy_clicked(enemy: EnemyCard):
		selected_enemy = enemy

	func _on_shift_button_pressed(direction: String):
		shift_direction = direction

	func _clear_all_targeting_ui():
		clear_count += 1

	func _on_enemy_hovered(_enemy: EnemyCard):
		enemy_hover_count += 1

	func _on_enemy_unhovered(_enemy: EnemyCard):
		enemy_unhover_count += 1


func test_activate_slot_emits_only_for_visible_enabled_semantic_slot() -> void:
	var bar := ActionBar.new()
	bar.actions_ui = Control.new()
	bar.add_child(bar.actions_ui)
	for index in 4:
		var action_button := ActionButtonScene.instantiate() as ActionButton
		action_button.button = action_button.get_node("Button")
		action_button.visible = index != 3
		action_button.button.disabled = index == 2
		bar.actions_ui.add_child(action_button)
	autofree(bar)
	watch_signals(bar)
	assert_true(bar.activate_slot(0))
	assert_true(bar.activate_slot(1))
	assert_false(bar.activate_slot(2), "disabled/unaffordable actions do nothing")
	assert_false(bar.activate_slot(3), "hidden actions do nothing")
	assert_false(bar.activate_slot(-1))
	assert_false(bar.activate_slot(4), "missing actions do nothing")
	assert_signal_emit_count(bar, "action_selected", 2)


func test_semantic_actions_activate_matching_slots_without_gui_focus() -> void:
	var bar := ActionBar.new()
	bar.actions_ui = Control.new()
	bar.add_child(bar.actions_ui)
	bar.buttons_disabled = false
	bar.sliding = false
	for index in 4:
		var action_button := ActionButtonScene.instantiate() as ActionButton
		action_button.button = action_button.get_node("Button")
		bar.actions_ui.add_child(action_button)
	autofree(bar)
	watch_signals(bar)
	for index in 4:
		bar._unhandled_input(_action_event(StringName("action_%d" % (index + 1))))
	assert_signal_emit_count(bar, "action_selected", 4)
	assert_null(get_viewport().gui_get_focus_owner(), "direct actions never traverse action-button focus")
	bar.buttons_disabled = true
	bar._unhandled_input(_action_event(&"action_1"))
	assert_signal_emit_count(bar, "action_selected", 4)


func test_shift_binding_uses_existing_available_shift_direction() -> void:
	var bar := ActionBar.new()
	bar.buttons_disabled = false
	bar.sliding = false
	bar.left_shift_ui = Control.new()
	bar.right_shift_ui = Control.new()
	bar.left_shift_button = Button.new()
	bar.right_shift_button = Button.new()
	bar.add_child(bar.left_shift_ui)
	bar.add_child(bar.right_shift_ui)
	bar.left_shift_ui.add_child(bar.left_shift_button)
	bar.right_shift_ui.add_child(bar.right_shift_button)
	autofree(bar)
	bar.left_shift_ui.visible = false
	bar.right_shift_ui.visible = true
	watch_signals(bar)
	bar._unhandled_input(_action_event(&"shift_action"))
	assert_signal_emitted_with_parameters(bar, "shift_button_pressed", ["right"])
	bar.right_shift_button.disabled = true
	bar._unhandled_input(_action_event(&"shift_action"))
	assert_signal_emit_count(bar, "shift_button_pressed", 1)


func test_target_navigation_filters_invalid_cards_and_uses_geometry() -> void:
	var fixture := _battle_fixture()
	var scene: TrackingBattleScene = fixture.scene
	var first: EnemyCard = fixture.first
	var defeated: EnemyCard = fixture.defeated
	var right: EnemyCard = fixture.right
	scene._controller_target = first
	scene.select_direction(Vector2.RIGHT)
	assert_same(scene._controller_target, right)
	scene.select_direction(Vector2.LEFT)
	assert_same(scene._controller_target, first)
	assert_ne(scene._controller_target, defeated)
	scene.select_direction(Vector2.LEFT)
	assert_same(scene._controller_target, right, "edge navigation cycles through valid targets")


func test_held_direction_repeats_after_delay() -> void:
	var fixture := _battle_fixture()
	var scene: TrackingBattleScene = fixture.scene
	var first: EnemyCard = fixture.first
	var right: EnemyCard = fixture.right
	scene._controller_target = first
	scene.process_controller_direction(Vector2.RIGHT, 0.0)
	assert_same(scene._controller_target, right)
	scene.process_controller_direction(Vector2.RIGHT, BattleScene.REPEAT_DELAY)
	assert_same(scene._controller_target, first, "held navigation repeats and cycles")


func test_confirm_delegates_to_existing_selection_and_cancel_never_executes() -> void:
	var fixture := _battle_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var first: EnemyCard = fixture.first
	scene._controller_target = first
	scene.confirm_target()
	assert_same(manager.selected_enemy, first)
	manager.selected_enemy = null
	manager.current_state = BattleManager.State.FORCED_TARGET
	scene._controller_target = first
	scene.cancel_targeting()
	assert_null(manager.selected_enemy, "cancel does not execute")
	assert_eq(manager.current_state, BattleManager.State.PLAYER_ACTION)
	assert_same(scene._controller_target, manager.current_actor, "cursor region returns to active hero")


func test_confirm_is_not_consumed_outside_targeting_or_confused_with_action_one() -> void:
	var fixture := _battle_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	manager.current_state = BattleManager.State.PLAYER_ACTION
	manager.current_action = null
	scene._controller_target = manager.current_actor
	scene._unhandled_input(_action_event(&"confirm"))
	assert_null(manager.selected_hero)
	assert_null(manager.selected_enemy)


func test_mouse_mode_clears_synthetic_controller_hover_without_selecting() -> void:
	var fixture := _battle_fixture()
	var scene: TrackingBattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var first: EnemyCard = fixture.first
	scene._controller_target = first
	scene._on_input_mode_changed(InputManager.InputMode.MOUSE)
	assert_eq(manager.enemy_unhover_count, 1)
	assert_same(scene._controller_target, manager.current_actor)
	assert_eq(scene.cursor_update_count, 1, "semantic cursor target returns to the active hero")
	assert_null(manager.selected_enemy)


func test_action_button_glyph_dims_with_disabled_state() -> void:
	var action_button := ActionButtonScene.instantiate() as ActionButton
	action_button.button = action_button.get_node("Button")
	action_button.dynamic_glyph = action_button.get_node("DynamicGlyph")
	autofree(action_button)
	action_button.disabled = true
	assert_lt(action_button.dynamic_glyph.modulate.a, 1.0)
	action_button.disabled = false
	assert_eq(action_button.dynamic_glyph.modulate.a, 1.0)


func _battle_fixture() -> Dictionary:
	var scene := TrackingBattleScene.new()
	var manager := TrackingBattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	var hero := HeroCard.new()
	hero.position = Vector2(100, 300)
	hero.is_defeated = false
	hero_area.add_child(hero)
	var first := EnemyCard.new()
	first.position = Vector2(100, 100)
	first.is_valid_target = true
	first.is_defeated = false
	enemy_area.add_child(first)
	var defeated := EnemyCard.new()
	defeated.position = Vector2(200, 100)
	defeated.is_valid_target = true
	defeated.is_defeated = true
	enemy_area.add_child(defeated)
	var right := EnemyCard.new()
	right.position = Vector2(300, 100)
	right.is_valid_target = true
	right.is_defeated = false
	enemy_area.add_child(right)
	manager.current_actor = hero
	manager.current_state = BattleManager.State.FORCED_TARGET
	scene.manager = manager
	scene.add_child(manager)
	scene.add_child(hero_area)
	scene.add_child(enemy_area)
	autofree(scene)
	return {scene = scene, manager = manager, first = first, defeated = defeated, right = right}


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
