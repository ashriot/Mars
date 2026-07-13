extends GutTest

const ActionButtonScene := preload("res://src/battle/action_button.tscn")
const UXScene := preload("res://src/ui/navigation/navigation_ux_layer.tscn")


class MinimalActionBar extends ActionBar:
	func _ready() -> void:
		pass


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
	var action_select_count := 0
	var confirm_count := 0
	var forced_target: EnemyCard

	func _ready() -> void:
		if action_bar:
			action_bar.action_selected.connect(_on_action_button_pressed)

	func _on_action_button_pressed(button: ActionButton):
		action_select_count += 1
		focused_button = button
		current_action = button.action
		if forced_target:
			forced_target.is_valid_target = true

	func _on_hero_clicked(hero: HeroCard):
		selected_hero = hero

	func _on_enemy_clicked(enemy: EnemyCard):
		selected_enemy = enemy
		confirm_count += 1

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


func test_standard_right_direction_changes_battle_target() -> void:
	var fixture := _battle_fixture()
	var scene: BattleScene = fixture.scene
	var first: EnemyCard = fixture.first
	var right: EnemyCard = fixture.right
	scene._controller_target = first
	Input.action_press(&"ui_right")
	scene._process(0.0)
	Input.action_release(&"ui_right")
	assert_same(scene._controller_target, right)


func test_battle_target_change_snaps_target_cursor_to_selected_actor() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	manager.current_action = Action.new()
	fixture.enemy.is_valid_target = true
	scene._set_controller_target(fixture.enemy)
	assert_same(scene._controller_target, fixture.enemy)
	assert_eq(manager.enemy_hover_count, 1)
	assert_same(fixture.ux.cursor._target, fixture.enemy)
	assert_eq(fixture.ux.cursor._state, NavigationCursor.CursorState.DEFAULT)
	assert_eq(fixture.ux.cursor.texture.resource_path.get_file(), "pointer_c.svg")
	fixture.ux.cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2.ZERO, true)
	assert_true(fixture.ux.cursor.visible)


func test_self_targeting_refresh_places_cursor_on_active_hero() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	manager.current_action = Action.new()
	manager.current_action.target_type = Action.TargetType.SELF
	fixture.hero.is_valid_target = true
	fixture.enemy.is_valid_target = false
	scene._controller_target = fixture.hero
	fixture.ux.cursor.clear_target()
	scene._refresh_targeting()
	assert_same(scene._controller_target, fixture.hero)
	assert_same(fixture.ux.cursor._target, fixture.hero)
	assert_eq(fixture.ux.cursor._state, NavigationCursor.CursorState.DEFAULT)


func test_selected_action_hotkey_toggles_targeting_off() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var bar: ActionBar = fixture.bar
	bar._unhandled_input(_action_event(&"action_1"))
	assert_not_null(manager.current_action)
	assert_same(manager.focused_button, bar.actions_ui.get_child(0))
	bar._unhandled_input(_action_event(&"action_1"))
	assert_null(manager.current_action)
	assert_null(manager.focused_button)
	assert_eq(manager.current_state, BattleManager.State.PLAYER_ACTION)
	assert_eq(manager.clear_count, 1)
	assert_same(scene._controller_target, manager.current_actor)


func test_different_action_hotkey_replaces_current_selection() -> void:
	var fixture := await _navigation_fixture()
	var manager: TrackingBattleManager = fixture.manager
	var bar: ActionBar = fixture.bar
	var second := bar.actions_ui.get_child(1) as ActionButton
	second.button.disabled = false
	bar._unhandled_input(_action_event(&"action_1"))
	bar._unhandled_input(_action_event(&"action_2"))
	assert_eq(manager.action_select_count, 2)
	assert_same(manager.current_action, second.action)
	assert_same(manager.focused_button, second)


func test_battle_action_hotkey_snaps_then_free_mouse_continues_from_target() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	manager.current_action = Action.new()
	fixture.enemy.is_valid_target = true
	InputManager._set_cursor_behavior(InputManager.CursorBehavior.FREE)
	InputManager._input(_physical_key(KEY_1))
	assert_eq(InputManager.get_cursor_behavior(), InputManager.CursorBehavior.SNAPPED)
	scene._set_controller_target(fixture.enemy)
	var target_position: Vector2 = fixture.enemy.global_position + fixture.enemy.size * 0.5
	fixture.ux.cursor.update_position_for_behavior(InputManager.CursorBehavior.SNAPPED, Vector2(20, 20), true)
	assert_eq(fixture.ux.cursor.position, target_position)
	assert_true(fixture.ux.cursor.visible)

	var motion := InputEventMouseMotion.new()
	motion.position = target_position + Vector2(12, 0)
	motion.relative = Vector2(12, 0)
	InputManager._input(motion)
	fixture.ux.cursor.update_position_for_behavior(InputManager.CursorBehavior.FREE, motion.position, true)
	assert_eq(fixture.ux.cursor.position, motion.position)
	assert_true(fixture.ux.cursor.visible)
	assert_same(scene._controller_target, fixture.enemy)


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
	scene._on_input_mode_changed(InputManager.InputMode.KEYBOARD_MOUSE)
	assert_eq(manager.enemy_unhover_count, 1)
	assert_same(scene._controller_target, manager.current_actor)
	assert_eq(scene.cursor_update_count, 1, "semantic cursor target returns to the active hero")
	assert_null(manager.selected_enemy)


func test_action_button_glyph_dims_with_disabled_state() -> void:
	InputManager._input(_pressed_joy_button())
	var action_button := ActionButtonScene.instantiate() as ActionButton
	add_child_autofree(action_button)
	await get_tree().process_frame
	InputManager._input(_pressed_key())
	action_button.dynamic_glyph.set_action(&"action_1")
	action_button.disabled = true
	assert_eq(action_button.dynamic_glyph.texture_normal.resource_path.get_file(), "keyboard_1.svg")
	assert_null(action_button.dynamic_glyph.get_node_or_null("KeyboardLabel"))
	assert_lt(action_button.dynamic_glyph.modulate.a, 1.0)
	action_button.disabled = false
	assert_eq(action_button.dynamic_glyph.modulate.a, 1.0)


func test_action_button_glyph_has_opaque_backing_below_texture() -> void:
	var action_button := ActionButtonScene.instantiate() as ActionButton
	add_child_autofree(action_button)
	await get_tree().process_frame
	var backing := action_button.get_node_or_null("GlyphBacking") as Panel
	assert_not_null(backing)
	assert_lt(backing.get_index(), action_button.dynamic_glyph.get_index())
	var style := backing.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(style)
	assert_eq(style.bg_color.a, 1.0)


func test_real_action_buttons_switch_between_keyboard_and_controller_glyphs() -> void:
	InputManager._input(_pressed_joy_button())
	var buttons: Array[ActionButton] = []
	for index in 4:
		var button := ActionButtonScene.instantiate() as ActionButton
		button.glyph_action = StringName("action_%d" % (index + 1))
		add_child_autofree(button)
		buttons.append(button)
	await get_tree().process_frame

	InputManager._input(_pressed_key())
	for index in 4:
		assert_eq(buttons[index].dynamic_glyph.texture_normal.resource_path.get_file(), "keyboard_%d.svg" % (index + 1))
		assert_null(buttons[index].dynamic_glyph.get_node_or_null("KeyboardLabel"))

	InputManager._input(_pressed_joy_button())
	for index in 4:
		var expected := ["steamdeck_button_a.svg", "steamdeck_button_b.svg", "steamdeck_button_x.svg", "steamdeck_button_y.svg"]
		assert_eq(buttons[index].dynamic_glyph.texture_normal.resource_path.get_file(), expected[index])
		assert_null(buttons[index].dynamic_glyph.get_node_or_null("KeyboardLabel"))


func test_real_shift_controls_switch_between_keyboard_and_controller_glyphs() -> void:
	InputManager._input(_pressed_joy_button())
	var manager := TrackingBattleManager.new()
	add_child_autofree(manager)
	var bar := preload("res://src/battle/action_bar.tscn").instantiate() as ActionBar
	bar.battle_manager = manager
	add_child_autofree(bar)
	await get_tree().process_frame
	var shift_glyphs: Array[DynamicGlyph] = [
		bar.get_node("LeftShift/DynamicGlyph") as DynamicGlyph,
		bar.get_node("RightShift/DynamicGlyph") as DynamicGlyph,
	]

	InputManager._input(_pressed_key())
	for glyph: DynamicGlyph in shift_glyphs:
		assert_eq(glyph.texture_normal.resource_path.get_file(), "keyboard_shift.svg")
		assert_null(glyph.get_node_or_null("KeyboardLabel"))

	InputManager._input(_pressed_joy_button())
	var expected_trigger := InputIconMap.get_glyph(
		InputManager.get_active_controller_type(),
		&"shift_action",
	)
	for glyph: DynamicGlyph in shift_glyphs:
		assert_same(glyph.texture_normal, expected_trigger)
		assert_null(glyph.get_node_or_null("KeyboardLabel"))


func test_combat_clears_global_hints_during_action_selection() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var ux: NavigationUXLayer = fixture.ux
	ux.publish_hints([{action = &"confirm", label = "Previous Screen", enabled = true}])
	assert_eq(ux.hint_bar.get_hint_count(), 1)
	scene._publish_controller_hints()
	assert_eq(ux.hint_bar.get_hint_count(), 0, "combat buttons already display their own input glyphs")


func test_combat_keeps_global_hints_hidden_during_targeting() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var ux: NavigationUXLayer = fixture.ux
	manager.current_action = Action.new()
	fixture.enemy.is_valid_target = true
	scene._controller_target = fixture.enemy
	ux.publish_hints([{action = &"cancel", label = "Previous Screen", enabled = true}])
	assert_eq(ux.hint_bar.get_hint_count(), 1)
	scene._publish_controller_hints()
	assert_eq(ux.hint_bar.get_hint_count(), 0, "targeting remains readable without a redundant global panel")


func test_physical_button_zero_selects_then_distinct_press_confirms() -> void:
	var fixture := await _navigation_fixture()
	var manager: TrackingBattleManager = fixture.manager
	assert_true(InputMap.event_is_action(_joy_button_zero(), &"confirm"))
	assert_true(InputMap.event_is_action(_joy_button_zero(), &"action_1"))
	Input.parse_input_event(_joy_button_zero())
	await get_tree().process_frame
	assert_eq(manager.action_select_count, 1)
	assert_eq(manager.confirm_count, 0, "slot selection must not confirm in the same physical press")
	Input.parse_input_event(_joy_button_zero())
	await get_tree().process_frame
	assert_eq(manager.action_select_count, 1, "targeting press must not reselect the action")
	assert_eq(manager.confirm_count, 1)


func test_top_modal_suppresses_battle_input_and_restores_adapter_cursor() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var ux: NavigationUXLayer = fixture.ux
	var modal := Control.new()
	var modal_button := Button.new()
	modal.add_child(modal_button)
	add_child_autofree(modal)
	ux.push_modal(modal, modal_button)
	await get_tree().process_frame
	assert_same(ux.get_focus_target(), modal_button)
	assert_same(ux.cursor._target, modal_button)
	fixture.bar._unhandled_input(_action_event(&"action_1"))
	scene._unhandled_input(_action_event(&"confirm"))
	assert_eq(manager.action_select_count, 0)
	assert_eq(manager.confirm_count, 0)
	ux.pop_modal(modal)
	await get_tree().process_frame
	assert_same(ux._adapter, scene)
	assert_same(scene._controller_target, manager.current_actor)
	assert_null(ux.cursor._target)
	assert_eq(ux.cursor._state, NavigationCursor.CursorState.DEFAULT)
	assert_eq(ux.cursor.texture.resource_path.get_file(), "pointer_c.svg")


func test_battle_phase_restore_clears_specialized_cursor_appearance() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var ux: NavigationUXLayer = fixture.ux
	ux.cursor.set_world_target(manager.current_actor, NavigationCursor.CursorState.TARGET)
	manager.current_state = BattleManager.State.PLAYER_ACTION
	scene.navigation_focus_restored()
	assert_same(scene._controller_target, manager.current_actor)
	assert_null(ux.cursor._target)
	assert_eq(ux.cursor._state, NavigationCursor.CursorState.DEFAULT)
	assert_eq(ux.cursor.texture.resource_path.get_file(), "pointer_c.svg")


func test_battle_adapter_teardown_clears_global_cursor_hints_and_refs() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var ux: NavigationUXLayer = fixture.ux
	assert_same(ux._adapter, scene)
	scene.free()
	await get_tree().process_frame
	assert_null(ux._adapter)
	assert_null(ux.cursor._target)
	assert_eq(ux.hint_bar.get_hint_count(), 0)


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


func _joy_button_zero() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func _pressed_key() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_F12
	event.pressed = true
	return event


func _physical_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _pressed_joy_button() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	return event


func _navigation_fixture() -> Dictionary:
	var ux := UXScene.instantiate() as NavigationUXLayer
	add_child_autofree(ux)
	var scene := BattleScene.new()
	var manager := TrackingBattleManager.new()
	var bar := MinimalActionBar.new()
	var actions := Control.new()
	actions.name = "Actions"
	bar.actions_ui = actions
	bar.add_child(actions)
	var left_shift := Control.new()
	left_shift.name = "LeftShift"
	var left_button := Button.new()
	left_button.name = "Button"
	left_shift.add_child(left_button)
	left_shift.visible = false
	bar.add_child(left_shift)
	var right_shift := Control.new()
	right_shift.name = "RightShift"
	var right_button := Button.new()
	right_button.name = "Button"
	right_shift.add_child(right_button)
	right_shift.visible = false
	bar.add_child(right_shift)
	for index in 3:
		var action_button := ActionButtonScene.instantiate() as ActionButton
		action_button.button = action_button.get_node("Button")
		action_button.label = action_button.get_node("Title")
		action_button.action = Action.new()
		action_button.visible = index != 2
		action_button.button.disabled = index == 1
		action_button.label.text = "Action %d" % (index + 1)
		actions.add_child(action_button)
	var passive := Panel.new()
	passive.name = "Passive"
	actions.add_child(passive)
	var shift_action_panel := Panel.new()
	shift_action_panel.name = "ShiftAction"
	actions.add_child(shift_action_panel)
	bar.battle_manager = manager
	bar.buttons_disabled = false
	bar.sliding = false
	manager.action_bar = bar
	manager.current_state = BattleManager.State.PLAYER_ACTION
	var hero := preload("res://src/battle/hero_card.tscn").instantiate() as HeroCard
	var enemy := preload("res://src/battle/enemy_card.tscn").instantiate() as EnemyCard
	hero.battle_manager = manager
	enemy.battle_manager = manager
	hero.is_defeated = false
	enemy.is_defeated = false
	enemy.is_valid_target = false
	var hero_area := Control.new()
	var enemy_area := Control.new()
	hero_area.add_child(hero)
	enemy_area.add_child(enemy)
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	manager.current_actor = hero
	manager.forced_target = enemy
	scene.manager = manager
	scene.add_child(manager)
	scene.add_child(hero_area)
	scene.add_child(enemy_area)
	scene.add_child(bar)
	add_child_autofree(scene)
	await get_tree().process_frame
	return {scene = scene, manager = manager, bar = bar, ux = ux, hero = hero, enemy = enemy}
