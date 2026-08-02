extends GutTest

const CardSceneTestFixture := preload("res://test/helpers/card_scene_test_fixture.gd")

const ActionButtonScene := preload("res://src/battle/action_button.tscn")
const UXScene := preload("res://src/ui/navigation/navigation_ux_layer.tscn")
const SYNTHETIC_UNCONNECTED_JOY_DEVICE := 127


class MinimalActionBar extends ActionBar:
	func _ready() -> void:
		pass


class PausingShiftActionBar extends MinimalActionBar:
	signal continue_slide_out

	func slide_out(_duration: float = 0.2):
		await continue_slide_out


class ImmediateShiftActionBar extends MinimalActionBar:
	func slide_out(_duration: float = 0.2):
		return

	func slide_in(_duration: float = 0.2):
		return

	func update_action_bar(_hero_card: HeroCard, _shifted: bool = false):
		return


class ImmediateShiftHero extends HeroCard:
	func shift_role(_direction: String):
		(combatant as HeroCombatant).current_role_index = 1

	func set_target_presentation(_state: TargetPresentation) -> void:
		return


class ShiftEventEffect extends ActionEffect:
	var event_name: String
	var events: Array[String]

	func _init(recorded_event: String, event_log: Array[String]) -> void:
		event_name = recorded_event
		events = event_log

	func execute(
		_attacker: ActorCard,
		_parent_targets: Array,
		_battle_manager: BattleManager,
		_action: Action = null,
		_context: Dictionary = {},
	) -> void:
		events.append(event_name)


class LethalShiftEffect extends ActionEffect:
	var events: Array[String]

	func _init(event_log: Array[String]) -> void:
		events = event_log

	func execute(
		_attacker: ActorCard,
		parent_targets: Array,
		battle_manager: BattleManager,
		_action: Action = null,
		_context: Dictionary = {},
	) -> void:
		events.append("shift_action")
		for target: ActorCard in parent_targets:
			target.is_defeated = true
		await battle_manager._check_if_battle_ended()


class ShiftReactionHero extends HeroCard:
	var events: Array[String]

	func shift_role(_direction: String):
		(combatant as HeroCombatant).current_role_index = 1
		events.append("role_changed")
		await _fire_condition_event(Trigger.TriggerType.ON_SHIFT)

	func set_target_presentation(_state: TargetPresentation) -> void:
		return


class ShiftReactionEnemy extends EnemyCard:
	func set_target_presentation(_state: TargetPresentation) -> void:
		return


class ShiftReactionBattleManager extends BattleManager:
	func wait(_duration: float = 0.01) -> void:
		return

	func _flush_all_health_animations() -> void:
		return

	func _fade_out(_duration: float = 0.5):
		return

	func _update_all_enemy_intents() -> void:
		return

	func update_turn_order() -> void:
		return

	func set_current_action(action: Action):
		current_action = action
		for target: ActorCard in get_targets(
			action.target_type, true, [], null, action.can_revive_targets,
		):
			target.is_valid_target = true

	func execute_action(
		actor: ActorCard,
		action: Action,
		targets: Array,
		_display_name: bool = true,
		_ends_turn: bool = false,
	):
		executing_action = action
		current_action = null
		for effect: ActionEffect in action.effects:
			await effect.execute(actor, targets, self, action, {})


class ShiftReactionFixture extends RefCounted:
	var manager: ShiftReactionBattleManager
	var hero: ShiftReactionHero
	var target: HeroCard
	var events: Array[String]

	func free_all() -> void:
		manager.free()


class RemoveConditionsEffect extends ActionEffect:
	func execute(
		attacker: ActorCard,
		_parent_targets: Array,
		_battle_manager: BattleManager,
		_action: Action = null,
		_context: Dictionary = {}
	) -> void:
		attacker.active_conditions.clear()


class RecoveryBattleManager extends BattleManager:
	func _flush_all_health_animations() -> void:
		return

	func _apply_role_passive(_hero: HeroCard):
		return


class TrackingBattleScene extends BattleScene:
	pass

class TrackingBattleManager extends BattleManager:
	var selected_hero: HeroCard
	var selected_enemy: EnemyCard
	var shift_direction := ""
	var clear_count := 0
	var action_select_count := 0
	var confirm_count := 0
	var forced_target: EnemyCard
	var preview_targets: Array[ActorCard] = []
	var ordinary_preview_count := 0

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
		super._clear_all_targeting_ui()

	func preview_action_turn_order(_actor: ActorCard, _action: Action, selected_target: ActorCard = null):
		preview_targets.append(selected_target)

	func update_turn_order():
		ordinary_preview_count += 1

	func _update_all_enemy_intents():
		pass

	func _check_if_battle_ended() -> bool:
		return false


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


func test_directional_shift_actions_activate_only_their_matching_available_side() -> void:
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
	watch_signals(bar)

	bar._unhandled_input(_action_event(&"shift_left"))
	assert_signal_emitted_with_parameters(bar, "shift_button_pressed", ["left"])
	bar._unhandled_input(_action_event(&"shift_right"))
	assert_signal_emitted_with_parameters(bar, "shift_button_pressed", ["right"])
	assert_signal_emit_count(bar, "shift_button_pressed", 2, "both cards may show the same role")

	bar.left_shift_ui.visible = false
	bar._unhandled_input(_action_event(&"shift_left"))
	assert_signal_emit_count(bar, "shift_button_pressed", 2, "left never falls back to right")
	bar.right_shift_button.disabled = true
	bar._unhandled_input(_action_event(&"shift_right"))
	assert_signal_emit_count(bar, "shift_button_pressed", 2, "right never falls back to left")


func test_directional_shift_fully_supersedes_selected_action_before_role_ui_loads() -> void:
	var manager := BattleManager.new()
	var bar := PausingShiftActionBar.new()
	var shift_ui := Control.new()
	var shift_button := Button.new()
	shift_ui.add_child(shift_button)
	bar.right_shift_ui = shift_ui
	bar.right_shift_button = shift_button
	bar.add_child(shift_ui)
	bar.battle_manager = manager
	manager.action_bar = bar
	bar.shift_button_pressed.connect(manager._on_shift_button_pressed)

	var current_action_panel := PanelContainer.new()
	manager.current_action_panel = current_action_panel
	var hero := CardSceneTestFixture.hero(self)
	manager.current_actor = hero
	manager.current_state = BattleManager.State.PLAYER_ACTION
	var action_button := ActionButtonScene.instantiate() as ActionButton
	action_button.action = Action.new()
	add_child_autofree(action_button)
	await get_tree().process_frame
	autofree(manager)
	autofree(bar)
	autofree(hero)
	autofree(current_action_panel)

	manager._focus_button(action_button)
	manager.current_action = action_button.action
	current_action_panel.show()
	assert_same(manager.current_action, action_button.action)
	assert_same(manager.focused_button, action_button)
	assert_true(action_button.highlight_panel.visible)
	assert_true(current_action_panel.visible)

	assert_true(bar.activate_shift("right"))
	assert_null(manager.current_action)
	assert_null(manager.focused_button)
	assert_false(action_button.highlight_panel.visible)
	assert_false(current_action_panel.visible)


func test_role_shift_publishes_queue_only_after_new_role_is_current() -> void:
	var manager := RecoveryBattleManager.new()
	var bar := ImmediateShiftActionBar.new()
	var hero := CardSceneTestFixture.bind(
		self, ImmediateShiftHero.new(), BattleCombatant.Faction.HERO, null, manager,
	) as ImmediateShiftHero
	var stats := ActorStats.new()
	stats.speed = 100
	hero.current_stats = stats
	hero.is_defeated = false
	var hero_model := hero.combatant as HeroCombatant
	for icon_color in [Color.RED, Color.BLUE]:
		var definition := RoleDefinition.new()
		definition.icon = GradientTexture2D.new()
		definition.color = icon_color
		var role := RoleData.new()
		role.source_definition = definition
		hero_model.loaded_roles.append(role)
	hero_model.current_role_index = 0
	manager.action_bar = bar
	manager.current_actor = hero
	manager.actor_list = [hero]
	manager.current_state = BattleManager.State.PLAYER_ACTION
	var publication := {count = 0, icons = []}
	manager.turn_order_updated.connect(func(queue: Array, _kind: BattleManager.TurnOrderUpdate) -> void:
		publication.count += 1
		for entry: Dictionary in queue:
			if entry.actor == hero:
				publication.icons.append((entry.actor as HeroCard).get_current_role().icon)
	)

	await manager._on_shift_button_pressed("right")

	assert_eq(
		publication.count,
		2,
		"role shift publishes after the role changes and after Shift reactions finish",
	)
	for icon in publication.icons:
		assert_same(icon, hero.loaded_roles[1].icon, "no publication exposes the old role icon")
	bar.free()
	hero.free()
	manager.free()


func test_after_shift_reaction_fires_after_automatic_shift_action() -> void:
	var fixture := _shift_reaction_fixture(true, false)

	await fixture.manager._on_shift_button_pressed("right")

	assert_eq(fixture.events, ["role_changed", "shift_action", "after_shift_action"])
	assert_null(fixture.manager.executing_action)
	fixture.free_all()


func test_lethal_automatic_shift_action_skips_post_victory_reaction() -> void:
	var fixture := _shift_reaction_fixture(true, false, true)

	await fixture.manager._on_shift_button_pressed("right")

	assert_eq(fixture.events, ["role_changed", "shift_action"])
	assert_eq(fixture.manager.current_state, BattleManager.State.BATTLE_OVER)
	assert_null(fixture.manager._pending_after_shift_action)
	assert_null(fixture.manager.executing_action)
	fixture.free_all()


func test_after_shift_reaction_waits_for_targeted_shift_action_target() -> void:
	var fixture := _shift_reaction_fixture(false, true)

	await fixture.manager._on_shift_button_pressed("right")

	assert_not_null(fixture.hero.get_current_role().passive)
	assert_null(
		fixture.manager.executing_action,
		"the completed role passive cannot block the Shift action target click",
	)
	assert_eq(fixture.events, ["role_changed"])
	await fixture.manager._on_hero_clicked(fixture.target)
	assert_eq(fixture.events, ["role_changed", "shift_action", "after_shift_action"])
	assert_null(fixture.manager.executing_action)
	fixture.free_all()


func test_shift_without_shift_action_still_finishes_reactions() -> void:
	var fixture := _shift_reaction_fixture(false, false)

	await fixture.manager._on_shift_button_pressed("right")

	assert_not_null(fixture.hero.get_current_role().passive)
	assert_eq(fixture.events, ["role_changed", "after_shift_action"])
	assert_null(
		fixture.manager.executing_action,
		"the completed role passive cannot block the hero's next action",
	)
	fixture.free_all()


func test_target_navigation_filters_invalid_cards_and_uses_geometry() -> void:
	var fixture := _battle_fixture()
	var scene: TrackingBattleScene = fixture.scene
	var first: EnemyCard = fixture.first
	var defeated: EnemyCard = fixture.defeated
	var right: EnemyCard = fixture.right
	scene._current_target = first
	scene.select_direction(Vector2.RIGHT)
	assert_same(scene._current_target, right)
	scene.select_direction(Vector2.LEFT)
	assert_same(scene._current_target, first)
	assert_ne(scene._current_target, defeated)
	scene.select_direction(Vector2.LEFT)
	assert_same(scene._current_target, right, "edge navigation cycles through valid targets")


func test_standard_right_direction_changes_battle_target() -> void:
	var fixture := _battle_fixture()
	var scene: BattleScene = fixture.scene
	var first: EnemyCard = fixture.first
	var right: EnemyCard = fixture.right
	scene._current_target = first
	Input.action_press(&"ui_right")
	scene._process(0.0)
	Input.action_release(&"ui_right")
	assert_same(scene._current_target, right)


func test_battle_target_change_uses_actor_highlight_without_cursor() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	manager.current_action = Action.new()
	fixture.enemy.is_valid_target = true
	scene._set_current_target(fixture.enemy)
	assert_same(scene._current_target, fixture.enemy)
	assert_eq(fixture.enemy.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
	assert_false(fixture.ux.cursor.visible)


func test_pointer_hover_selects_real_hero_and_enemy_cards_and_exit_clears_selection() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var hero: HeroCard = fixture.hero
	var enemy: EnemyCard = fixture.enemy
	manager.current_action = Action.new()
	manager.current_state = BattleManager.State.FORCED_TARGET
	hero.is_valid_target = true
	enemy.is_valid_target = true
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)

	enemy.panel.mouse_entered.emit()
	assert_same(scene._current_target, enemy)
	assert_eq(enemy.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
	assert_same(manager.preview_targets.back(), enemy)

	enemy.panel.mouse_exited.emit()
	hero.panel.mouse_entered.emit()
	assert_same(scene._current_target, hero)
	assert_eq(enemy.get_target_presentation(), ActorCard.TargetPresentation.AVAILABLE)
	assert_same(manager.preview_targets.back(), hero)

	hero.panel.mouse_exited.emit()
	assert_null(scene._current_target)
	assert_same(scene._navigation_origin, hero)
	assert_null(manager.preview_targets.back())


func test_exact_target_changes_refresh_selected_action_presentation_and_fall_back_to_neutral() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var hero: HeroCard = fixture.hero
	var defended: EnemyCard = fixture.enemy
	var breached: EnemyCard = fixture.second_enemy
	hero.current_stats = ActorStats.new()
	hero.current_stats.attack = 100
	hero.current_stats.overload = 50
	hero.current_stats.max_hp = 100
	hero.current_hp = 100
	defended.current_stats = ActorStats.new()
	defended.current_stats.kinetic_defense = 50
	defended.current_guard = 1
	breached.current_stats = ActorStats.new()
	breached.is_breached = true
	defended.is_valid_target = true
	breached.is_valid_target = true
	var effect := Effect_Damage.new()
	effect.damage_type = Action.DamageType.KINETIC
	effect.potency = 1.0
	var action := Action.new()
	action.target_type = Action.TargetType.ONE_ENEMY
	action.description = "{effect:1}"
	action.effects = [effect]
	manager.current_actor = hero
	manager.current_action = action
	var selected_button := fixture.bar.actions_ui.get_child(0) as ActionButton
	selected_button.action = action
	manager.focused_button = selected_button
	var panel := PanelContainer.new()
	var container := HBoxContainer.new()
	container.name = "HBoxContainer"
	var label := RichTextLabel.new()
	label.name = "Label"
	container.add_child(label)
	panel.add_child(container)
	manager.add_child(panel)
	manager.current_action_panel = panel
	var neutral_text := action.get_rich_description(hero)
	label.text = neutral_text
	selected_button.tooltip.bbcode_text = neutral_text
	assert_string_contains(neutral_text, "100% ATK")

	scene._set_current_target(defended)
	assert_string_contains(label.text, "Deals 50")
	assert_string_contains(selected_button.tooltip.bbcode_text, "Deals 50")

	scene._set_current_target(breached)
	assert_string_contains(label.text, "Deals 150")
	assert_string_contains(selected_button.tooltip.bbcode_text, "Deals 150")

	scene._clear_current_target(false)
	assert_string_contains(label.text, "100% ATK")
	assert_string_contains(selected_button.tooltip.bbcode_text, "100% ATK")

	breached.current_stats = null
	scene._set_current_target(breached)
	assert_string_contains(label.text, "100% ATK")
	assert_string_contains(selected_button.tooltip.bbcode_text, "100% ATK")

	breached.current_stats = ActorStats.new()
	action.target_type = Action.TargetType.RANDOM_ENEMY
	scene._set_current_target(defended)
	assert_string_contains(label.text, "100% ATK")
	assert_string_contains(selected_button.tooltip.bbcode_text, "100% ATK")
	scene._set_current_target(breached)
	assert_string_contains(label.text, "100% ATK")
	assert_string_contains(selected_button.tooltip.bbcode_text, "100% ATK")

	action.target_type = Action.TargetType.ONE_ENEMY
	scene._set_current_target(defended)
	assert_string_contains(selected_button.tooltip.bbcode_text, "Deals 50")
	var replacement_button := fixture.bar.actions_ui.get_child(1) as ActionButton
	manager._focus_button(replacement_button)
	assert_string_contains(selected_button.tooltip.bbcode_text, "100% ATK")

	manager._focus_button(selected_button)
	manager.current_action = action
	defended.is_valid_target = true
	breached.is_valid_target = true
	scene._set_current_target(defended)
	assert_string_contains(selected_button.tooltip.bbcode_text, "Deals 50")
	scene.cancel_targeting()
	assert_string_contains(selected_button.tooltip.bbcode_text, "100% ATK")


func test_shift_action_completion_resets_exact_target_button_presentation() -> void:
	var fixture := await _navigation_fixture()
	var manager: TrackingBattleManager = fixture.manager
	var hero: HeroCard = fixture.hero
	var defended: EnemyCard = fixture.enemy
	hero.current_stats = ActorStats.new()
	hero.current_stats.attack = 100
	hero.current_stats.max_hp = 100
	hero.current_hp = 100
	defended.current_stats = ActorStats.new()
	defended.current_stats.kinetic_defense = 50
	var effect := Effect_Damage.new()
	effect.damage_type = Action.DamageType.KINETIC
	effect.potency = 1.0
	var action := Action.new()
	action.target_type = Action.TargetType.ONE_ENEMY
	action.description = "{effect:1}"
	action.effects = [effect]
	action.is_shift_action = true
	var selected_button := fixture.bar.actions_ui.get_child(0) as ActionButton
	selected_button.action = action
	manager.current_actor = hero
	manager.focused_button = selected_button
	manager.executing_action = action
	manager.current_state = BattleManager.State.EXECUTING_ACTION
	selected_button.tooltip.bbcode_text = action.get_rich_description(hero, defended)

	assert_string_contains(selected_button.tooltip.bbcode_text, "Deals 50")
	await manager._finish_hero_turn()

	assert_string_contains(selected_button.tooltip.bbcode_text, "100% ATK")
	assert_null(manager.focused_button)


func test_controller_owned_pointer_hover_cannot_replace_current_target() -> void:
	var fixture := await _navigation_fixture()
	fixture.hero.is_valid_target = true
	fixture.enemy.is_valid_target = true
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	fixture.scene._set_current_target(fixture.enemy)
	fixture.hero.panel.mouse_entered.emit()
	assert_same(fixture.scene._current_target, fixture.enemy)


func test_self_targeting_refresh_retains_active_hero_without_cursor() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	manager.current_action = Action.new()
	manager.current_action.target_type = Action.TargetType.SELF
	fixture.hero.is_valid_target = true
	fixture.enemy.is_valid_target = false
	scene._current_target = fixture.hero
	scene._refresh_targeting()
	assert_same(scene._current_target, fixture.hero)


func test_controller_target_entry_restores_last_valid_same_side_target() -> void:
	var fixture := await _navigation_fixture()
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.scene._last_enemy_target = fixture.second_enemy
	fixture.scene._refresh_targeting()
	assert_same(fixture.scene._current_target, fixture.second_enemy)
	assert_eq(fixture.second_enemy.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
	assert_eq(fixture.enemy.get_target_presentation(), ActorCard.TargetPresentation.AVAILABLE)


func test_controller_target_entry_restores_and_falls_back_on_hero_side() -> void:
	var fixture := await _navigation_fixture()
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	var other_hero := preload("res://src/battle/hero_card.tscn").instantiate() as HeroCard
	CardSceneTestFixture.bind(
		self, other_hero, BattleCombatant.Faction.HERO, null, fixture.manager,
	)
	other_hero.is_defeated = false
	other_hero.reparent(fixture.manager.hero_area)
	fixture.hero.is_valid_target = true
	other_hero.is_valid_target = true
	fixture.scene._last_hero_target = other_hero
	fixture.scene._refresh_targeting()
	assert_same(fixture.scene._current_target, other_hero)
	fixture.scene._clear_current_target(false)
	other_hero.is_defeated = true
	fixture.scene._refresh_targeting()
	assert_same(fixture.scene._current_target, fixture.hero)


func test_invalid_remembered_target_falls_back_deterministically() -> void:
	var fixture := await _navigation_fixture()
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.second_enemy.is_defeated = true
	fixture.scene._last_enemy_target = fixture.second_enemy
	fixture.scene._refresh_targeting()
	assert_same(fixture.scene._current_target, fixture.enemy)


func test_keyboard_mouse_entry_starts_without_an_executable_target() -> void:
	var fixture := await _navigation_fixture()
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.scene._refresh_targeting()
	assert_null(fixture.scene._current_target)
	assert_null(fixture.scene._navigation_origin)
	assert_eq(fixture.enemy.get_target_presentation(), ActorCard.TargetPresentation.AVAILABLE)


func test_pointer_cleared_origin_restores_before_next_direction_moves() -> void:
	var fixture := await _navigation_fixture()
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.scene._set_current_target(fixture.enemy)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	fixture.scene._clear_current_target(true)
	fixture.scene.select_direction(Vector2.RIGHT)
	assert_same(fixture.scene._current_target, fixture.enemy)
	fixture.scene.select_direction(Vector2.RIGHT)
	assert_same(fixture.scene._current_target, fixture.second_enemy)


func test_all_enemy_action_selects_every_affected_card_and_requests_group_preview() -> void:
	var fixture := await _navigation_fixture()
	var action := Action.new()
	action.target_type = Action.TargetType.ALL_ENEMIES
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.manager._apply_target_presentation(action, [fixture.enemy, fixture.second_enemy])
	assert_eq(fixture.enemy.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
	assert_eq(fixture.second_enemy.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
	assert_eq(fixture.hero.get_target_presentation(), ActorCard.TargetPresentation.NORMAL)
	fixture.manager.current_actor = fixture.hero
	fixture.manager.current_action = action
	fixture.scene._refresh_target_preview()
	assert_eq(fixture.manager.preview_targets.size(), 1)
	assert_null(fixture.manager.preview_targets.back(), "group preview does not invent a single parent target")


func test_group_parent_ct_preview_projects_every_affected_actor() -> void:
	var manager := BattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area

	var hero := CardSceneTestFixture.hero(self)
	var first_enemy := CardSceneTestFixture.enemy(self)
	var second_enemy := CardSceneTestFixture.enemy(self)
	for actor: ActorCard in [hero, first_enemy, second_enemy]:
		var stats := ActorStats.new()
		stats.speed = 100
		actor.current_stats = stats
		actor.current_ct = 0
		actor.is_defeated = false
	hero.reparent(hero_area)
	first_enemy.reparent(enemy_area)
	second_enemy.reparent(enemy_area)
	manager.current_actor = hero
	manager.actor_list = [hero, first_enemy, second_enemy]

	var effect := Effect_ModifyCT.new()
	effect.ct_change_percent = 0.5
	assert_eq(effect.target_type, Action.TargetType.PARENT, "CT effects use PARENT by default")
	var action := Action.new()
	action.target_type = Action.TargetType.ALL_ENEMIES
	action.effects = [effect]
	var captured := {queue = []}
	manager.turn_order_updated.connect(func(queue: Array, _kind: BattleManager.TurnOrderUpdate) -> void:
		captured.queue = queue
	)

	manager.preview_action_turn_order(hero, action, null)

	for target: EnemyCard in [first_enemy, second_enemy]:
		var target_turn := (captured.queue as Array).filter(func(entry: Dictionary) -> bool:
			return entry.actor == target
		).front() as Dictionary
		assert_eq(target_turn.ticks_needed, 20, "every group target receives the projected 50% CT boost")
	assert_eq(first_enemy.current_ct, 0, "preview does not mutate live CT")
	assert_eq(second_enemy.current_ct, 0, "preview does not mutate live CT")
	manager.free()
	hero_area.free()
	enemy_area.free()


func test_turn_ending_action_applies_recovery_to_live_ct() -> void:
	var manager := BattleManager.new()
	var actor := _ct_actor(-500, 100)
	var action := Action.new()
	action.ct_cost_percent = 75

	await manager.execute_action(actor, action, [], false, true)

	assert_eq(actor.current_ct, 500)
	manager.free()
	actor.free()


func test_action_recovery_uses_multiplier_snapshot_from_execution_start() -> void:
	var manager := BattleManager.new()
	var actor := _ct_actor(-500, 100)
	var condition := Condition.new()
	condition.action_ct_multiplier = 0.75
	actor.active_conditions = [condition]
	var action := Action.new()
	action.effects = [RemoveConditionsEffect.new()]

	await manager.execute_action(actor, action, [], false, true)

	assert_true(actor.active_conditions.is_empty(), "the effect changes recovery modifiers during execution")
	assert_eq(actor.current_ct, 500, "recovery retains the 75% snapshot captured before effects")
	manager.free()
	actor.free()


func test_repeating_non_ct_preview_is_stable() -> void:
	var manager := BattleManager.new()
	var actor := _ct_actor(-500, 100)
	var rival := _ct_actor(600, 100)
	manager.current_actor = actor
	manager.actor_list = [actor, rival]
	var action := Action.new()
	action.ct_cost_percent = 75
	var projections: Array = []
	manager.turn_order_updated.connect(func(queue: Array, _kind: BattleManager.TurnOrderUpdate) -> void:
		projections.append(_projection_signature(queue))
	)

	manager.preview_action_turn_order(actor, action)
	manager.preview_action_turn_order(actor, action)

	assert_eq(projections.size(), 2)
	assert_eq(projections[0], projections[1])
	assert_eq(actor.current_ct, -500, "preview never mutates live CT")
	manager.free()
	actor.free()
	rival.free()


func test_preview_and_recovery_publish_the_same_next_future_actor() -> void:
	var manager := BattleManager.new()
	var actor := _ct_actor(-500, 100)
	var rival := _ct_actor(400, 100)
	manager.current_actor = actor
	manager.actor_list = [actor, rival]
	var action := Action.new()
	action.ct_cost_percent = 75
	var projections: Array[Array] = []
	manager.turn_order_updated.connect(func(queue: Array, _kind: BattleManager.TurnOrderUpdate) -> void:
		projections.append(queue)
	)

	manager.preview_action_turn_order(actor, action)
	manager.executing_action_ct_percent = actor.get_action_ct_percent(action)
	manager.executing_action_ends_turn = true
	manager._apply_executing_action_recovery(actor)

	assert_eq(projections.size(), 2)
	assert_same(projections[0][1].actor, actor, "the preview includes authored recovery")
	assert_same(projections[0][1].actor, projections[1][1].actor)
	manager.free()
	actor.free()
	rival.free()


func test_modifier_bearing_shift_preview_matches_non_turn_ending_execution() -> void:
	var manager := RecoveryBattleManager.new()
	var actor := _ct_actor(-500, 100)
	var rival := _ct_actor(600, 100)
	var condition := Condition.new()
	condition.action_ct_multiplier = 0.75
	actor.active_conditions = [condition]
	manager.current_actor = actor
	manager.actor_list = [actor, rival]
	var action := Action.new()
	action.is_shift_action = true
	var projections: Array[Array] = []
	manager.turn_order_updated.connect(func(queue: Array, _kind: BattleManager.TurnOrderUpdate) -> void:
		projections.append(queue)
	)

	manager.preview_action_turn_order(actor, action)
	await manager.execute_action(actor, action, [], false, false)
	manager.update_turn_order()

	assert_eq(actor.current_ct, -500, "shift execution does not apply recovery")
	assert_same(projections[0][1].actor, rival, "shift preview omits recovery despite active modifiers")
	assert_same(projections[0][1].actor, projections[1][1].actor)
	manager.free()
	actor.free()
	rival.free()


func test_invalid_current_target_falls_back_for_controller_and_clears_for_pointer() -> void:
	var fixture := await _navigation_fixture()
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.scene._set_current_target(fixture.enemy)
	fixture.enemy.is_defeated = true
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	fixture.scene._refresh_targeting()
	assert_same(fixture.scene._current_target, fixture.second_enemy)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	fixture.second_enemy.is_defeated = true
	fixture.scene._refresh_targeting()
	assert_null(fixture.scene._current_target)


func test_cancel_returns_all_cards_to_normal_and_stops_pulses() -> void:
	var fixture := await _navigation_fixture()
	fixture.enemy.is_valid_target = true
	fixture.scene._set_current_target(fixture.enemy)
	fixture.scene.cancel_targeting()
	for actor: ActorCard in [fixture.hero, fixture.enemy, fixture.second_enemy]:
		assert_eq(actor.get_target_presentation(), ActorCard.TargetPresentation.NORMAL)
		assert_null(actor._target_pulse_tween)


func test_cancel_suppresses_action_preview_and_restores_ordinary_turn_order() -> void:
	var fixture := await _navigation_fixture()
	var action := Action.new()
	var self_ct_effect := Effect_ModifyCT.new()
	self_ct_effect.target_type = Action.TargetType.SELF
	action.effects = [self_ct_effect]
	fixture.manager.current_action = action
	fixture.enemy.is_valid_target = true
	fixture.scene._set_current_target(fixture.enemy)
	fixture.manager.preview_targets.clear()
	fixture.manager.ordinary_preview_count = 0

	fixture.scene.cancel_targeting()

	assert_eq(fixture.manager.preview_targets.size(), 0, "cancel never republishes the outgoing action preview")
	assert_eq(fixture.manager.ordinary_preview_count, 1, "cancel explicitly restores the ordinary CTB projection")


func test_active_hero_turn_uses_slide_and_static_queue_gold_border() -> void:
	var hero := preload("res://src/battle/hero_card.tscn").instantiate() as HeroCard
	add_child_autofree(hero)
	await get_tree().process_frame
	CardSceneTestFixture.bind(self, hero, BattleCombatant.Faction.HERO)
	var definition := RoleDefinition.new()
	definition.color = Color(0.2, 0.65, 0.9, 1.0)
	var role := RoleData.new()
	role.source_definition = definition
	var hero_model := hero.combatant as HeroCombatant
	hero_model.loaded_roles = [role]
	hero_model.current_role_index = 0
	hero.recolor()
	hero._slide_up()
	await get_tree().create_timer(hero.duration + 0.01).timeout
	assert_eq(hero.panel.position, hero.panel_home_position + Vector2(0, hero.slide_offset_y))
	hero.highlight(true)
	assert_true(hero.highlight_panel.visible)
	assert_eq(hero.highlight_panel.modulate, Color.WHITE)
	var border := hero.highlight_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(border.border_color, CTBGauge.CURRENT_COLOR)
	assert_eq(border.border_width_left, 8)
	assert_eq(border.border_width_top, 8)
	assert_eq(border.border_width_right, 8)
	assert_eq(border.border_width_bottom, 8)


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
	assert_null(scene._current_target)


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


func test_keyboard_action_replacement_synchronously_clears_shared_target() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var bar: ActionBar = fixture.bar
	var second := bar.actions_ui.get_child(1) as ActionButton
	second.button.disabled = false
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	bar._unhandled_input(_action_event(&"action_1"))
	fixture.enemy.is_valid_target = true
	scene._set_current_target(fixture.enemy)
	assert_same(scene._current_target, fixture.enemy)

	bar._unhandled_input(_action_event(&"action_2"))

	assert_same(manager.current_action, second.action)
	assert_null(scene._current_target, "the outgoing target is not visible for the replacement action")
	assert_null(scene._navigation_origin, "replacement begins with no retained pointer/keyboard origin")


func test_hidden_remembered_target_uses_visible_controller_fallback() -> void:
	var fixture := await _navigation_fixture()
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.second_enemy.hide()
	fixture.scene._last_enemy_target = fixture.second_enemy
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)

	fixture.scene._refresh_targeting()

	assert_same(fixture.scene._current_target, fixture.enemy)


func test_hidden_first_candidate_is_excluded_from_controller_fallback() -> void:
	var fixture := await _navigation_fixture()
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.enemy.hide()
	fixture.scene._last_enemy_target = null
	fixture.scene._clear_current_target(false)
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)

	fixture.scene._refresh_targeting()

	assert_same(fixture.scene._current_target, fixture.second_enemy)


func test_real_death_path_immediately_restores_controller_fallback() -> void:
	var fixture := await _navigation_fixture()
	fixture.manager.current_action = Action.new()
	fixture.manager.actor_list = [fixture.hero, fixture.enemy, fixture.second_enemy]
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.enemy.actor_defeated.connect(fixture.manager._on_actor_died)
	InputManager._set_active_mode(InputManager.InputMode.CONTROLLER)
	fixture.scene._set_current_target(fixture.enemy)

	fixture.enemy.defeated()

	assert_same(fixture.scene._current_target, fixture.second_enemy)
	assert_same(fixture.scene._navigation_origin, fixture.second_enemy)
	assert_same(fixture.scene._last_enemy_target, fixture.second_enemy)


func test_real_death_path_immediately_clears_pointer_target_origin_and_memory() -> void:
	var fixture := await _navigation_fixture()
	fixture.manager.current_action = Action.new()
	fixture.manager.actor_list = [fixture.hero, fixture.enemy, fixture.second_enemy]
	fixture.enemy.is_valid_target = true
	fixture.second_enemy.is_valid_target = true
	fixture.enemy.actor_defeated.connect(fixture.manager._on_actor_died)
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	fixture.scene._set_current_target(fixture.enemy)

	fixture.enemy.defeated()

	assert_null(fixture.scene._current_target)
	assert_null(fixture.scene._navigation_origin)
	assert_null(fixture.scene._last_enemy_target)


func test_held_direction_repeats_after_delay() -> void:
	var fixture := _battle_fixture()
	var scene: TrackingBattleScene = fixture.scene
	var first: EnemyCard = fixture.first
	var right: EnemyCard = fixture.right
	scene._current_target = first
	scene.process_controller_direction(Vector2.RIGHT, 0.0)
	assert_same(scene._current_target, right)
	scene.process_controller_direction(Vector2.RIGHT, BattleScene.REPEAT_DELAY)
	assert_same(scene._current_target, first, "held navigation repeats and cycles")


func test_confirm_delegates_to_existing_selection_and_cancel_never_executes() -> void:
	var fixture := _battle_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var first: EnemyCard = fixture.first
	scene._set_current_target(first)
	scene.confirm_target()
	assert_same(manager.selected_enemy, first)
	manager.selected_enemy = null
	manager.current_state = BattleManager.State.FORCED_TARGET
	scene._set_current_target(first)
	scene.cancel_targeting()
	assert_null(manager.selected_enemy, "cancel does not execute")
	assert_eq(manager.current_state, BattleManager.State.PLAYER_ACTION)
	assert_null(scene._current_target, "target ownership clears after cancel")


func test_confirm_is_not_consumed_outside_targeting_or_confused_with_action_one() -> void:
	var fixture := _battle_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	manager.current_state = BattleManager.State.PLAYER_ACTION
	manager.current_action = null
	scene._current_target = manager.current_actor
	scene._unhandled_input(_action_event(&"confirm"))
	assert_null(manager.selected_hero)
	assert_null(manager.selected_enemy)


func test_mouse_mode_clears_synthetic_controller_hover_without_selecting() -> void:
	var fixture := _battle_fixture()
	var scene: TrackingBattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var first: EnemyCard = fixture.first
	scene._current_target = first
	scene._on_input_mode_changed(InputManager.InputMode.KEYBOARD_MOUSE)
	assert_same(scene._current_target, first)
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
	var left_glyph := bar.get_node("LeftShift/DynamicGlyph") as DynamicGlyph
	var right_glyph := bar.get_node("RightShift/DynamicGlyph") as DynamicGlyph

	InputManager._input(_pressed_key())
	assert_eq(left_glyph.texture_normal.resource_path.get_file(), "keyboard_q.svg")
	assert_eq(right_glyph.texture_normal.resource_path.get_file(), "keyboard_e.svg")

	InputManager._input(_pressed_joy_button())
	assert_same(left_glyph.texture_normal, InputIconMap.get_glyph(InputManager.get_active_controller_type(), &"shift_left"))
	assert_same(right_glyph.texture_normal, InputIconMap.get_glyph(InputManager.get_active_controller_type(), &"shift_right"))


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
	scene._current_target = fixture.enemy
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


func test_top_modal_suppresses_battle_input_and_restores_adapter_focus() -> void:
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
	assert_true(NavigationFocus._states.has(modal_button.get_instance_id()))
	assert_false(ux.cursor.visible)
	fixture.bar._unhandled_input(_action_event(&"action_1"))
	scene._unhandled_input(_action_event(&"confirm"))
	assert_eq(manager.action_select_count, 0)
	assert_eq(manager.confirm_count, 0)
	ux.pop_modal(modal)
	await get_tree().process_frame
	assert_same(ux._adapter, scene)
	assert_null(scene._current_target)
	assert_false(ux.cursor.visible)


func test_battle_phase_restore_retains_active_actor_without_cursor() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var manager: TrackingBattleManager = fixture.manager
	var ux: NavigationUXLayer = fixture.ux
	manager.current_state = BattleManager.State.PLAYER_ACTION
	scene.navigation_focus_restored()
	assert_null(scene._current_target)
	assert_false(ux.cursor.visible)


func test_battle_adapter_teardown_clears_target_presentation_cursor_hints_and_refs() -> void:
	var fixture := await _navigation_fixture()
	var scene: BattleScene = fixture.scene
	var ux: NavigationUXLayer = fixture.ux
	fixture.enemy.is_valid_target = true
	scene._set_current_target(fixture.enemy)
	assert_eq(fixture.enemy.get_target_presentation(), ActorCard.TargetPresentation.SELECTED)
	assert_same(ux._adapter, scene)
	scene.get_parent().remove_child(scene)
	await get_tree().process_frame
	assert_eq(fixture.enemy.get_target_presentation(), ActorCard.TargetPresentation.NORMAL)
	assert_null(fixture.enemy._target_pulse_tween)
	assert_null(ux._adapter)
	assert_false(ux.cursor.visible)
	assert_eq(ux.hint_bar.get_hint_count(), 0)
	scene.free()


func _shift_reaction_fixture(
	automatic_action: bool,
	targeted_action: bool,
	lethal_action: bool = false,
) -> ShiftReactionFixture:
	var fixture := ShiftReactionFixture.new()
	fixture.events = []
	fixture.manager = ShiftReactionBattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	var action_bar := ImmediateShiftActionBar.new()
	fixture.manager.add_child(hero_area)
	fixture.manager.add_child(enemy_area)
	fixture.manager.add_child(action_bar)
	fixture.manager.hero_area = hero_area
	fixture.manager.enemy_area = enemy_area
	fixture.manager.action_bar = action_bar
	fixture.manager.rewards_enabled = false
	fixture.hero = CardSceneTestFixture.bind(
		self, ShiftReactionHero.new(), BattleCombatant.Faction.HERO, null,
		fixture.manager,
	) as ShiftReactionHero
	fixture.hero.events = fixture.events
	fixture.hero.current_stats = ActorStats.new()
	fixture.hero.current_stats.speed = 100
	fixture.hero.is_defeated = false
	fixture.hero.battle_manager = fixture.manager
	fixture.target = CardSceneTestFixture.bind(
		self, ShiftReactionHero.new(), BattleCombatant.Faction.HERO, null,
		fixture.manager,
	) as ShiftReactionHero
	(fixture.target as ShiftReactionHero).events = fixture.events
	fixture.target.current_stats = ActorStats.new()
	fixture.target.is_defeated = false
	fixture.target.is_valid_target = true
	fixture.hero.reparent(hero_area)
	fixture.target.reparent(hero_area)
	if lethal_action:
		var enemy := CardSceneTestFixture.bind(
			self, ShiftReactionEnemy.new(), BattleCombatant.Faction.ENEMY, null,
			fixture.manager,
		) as ShiftReactionEnemy
		enemy.current_stats = ActorStats.new()
		enemy.is_defeated = false
		enemy.reparent(enemy_area)

	var hero_model := fixture.hero.combatant as HeroCombatant
	for _role_index in 2:
		var definition := RoleDefinition.new()
		definition.color = Color.WHITE
		var role := RoleData.new()
		role.source_definition = definition
		hero_model.loaded_roles.append(role)
	hero_model.current_role_index = 0
	var passive := Action.new()
	passive.action_name = "Shift passive"
	hero_model.loaded_roles[1].passive = passive

	if automatic_action or targeted_action:
		var action := Action.new()
		action.action_name = "Shift test"
		action.is_shift_action = true
		action.auto_target = automatic_action
		action.target_type = Action.TargetType.ALL_ENEMIES \
			if lethal_action else (
				Action.TargetType.SELF if automatic_action else Action.TargetType.ONE_ALLY
			)
		action.effects = [
			LethalShiftEffect.new(fixture.events) if lethal_action \
			else ShiftEventEffect.new("shift_action", fixture.events),
		]
		hero_model.loaded_roles[1].shift_action = action

	var after_shift_trigger := Trigger.new()
	after_shift_trigger.trigger_type = Trigger.TriggerType.AFTER_SHIFT_ACTION
	after_shift_trigger.effects_to_run = [
		ShiftEventEffect.new("after_shift_action", fixture.events),
	]
	var condition := Condition.new()
	condition.condition_name = "After Shift reaction"
	condition.attacker = fixture.hero
	condition.triggers = [after_shift_trigger]
	fixture.hero.active_conditions = [condition]
	fixture.manager.current_actor = fixture.hero
	fixture.manager.current_state = BattleManager.State.PLAYER_ACTION
	return fixture


func _ct_actor(current_ct: int, speed: int) -> EnemyCard:
	var actor := CardSceneTestFixture.enemy(self)
	actor.current_stats = ActorStats.new()
	actor.current_stats.speed = speed
	actor.current_ct = current_ct
	actor.is_defeated = false
	return actor


func _projection_signature(queue: Array) -> Array:
	var signature: Array = []
	for entry: Dictionary in queue:
		signature.append([entry.actor, entry.ticks_needed])
	return signature


func _battle_fixture() -> Dictionary:
	var scene := TrackingBattleScene.new()
	var manager := TrackingBattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	var hero := preload("res://src/battle/hero_card.tscn").instantiate() as HeroCard
	CardSceneTestFixture.bind(
		self, hero, BattleCombatant.Faction.HERO, null, manager,
	)
	hero.position = Vector2(100, 300)
	hero.is_defeated = false
	hero.reparent(hero_area)
	var first := preload("res://src/battle/enemy_card.tscn").instantiate() as EnemyCard
	CardSceneTestFixture.bind(
		self, first, BattleCombatant.Faction.ENEMY, null, manager,
	)
	first.position = Vector2(100, 100)
	first.is_valid_target = true
	first.is_defeated = false
	first.reparent(enemy_area)
	var defeated := preload("res://src/battle/enemy_card.tscn").instantiate() as EnemyCard
	CardSceneTestFixture.bind(
		self, defeated, BattleCombatant.Faction.ENEMY, null, manager,
	)
	defeated.position = Vector2(200, 100)
	defeated.is_valid_target = true
	defeated.is_defeated = true
	defeated.reparent(enemy_area)
	var right := preload("res://src/battle/enemy_card.tscn").instantiate() as EnemyCard
	CardSceneTestFixture.bind(
		self, right, BattleCombatant.Faction.ENEMY, null, manager,
	)
	right.position = Vector2(300, 100)
	right.is_valid_target = true
	right.is_defeated = false
	right.reparent(enemy_area)
	manager.current_actor = hero
	manager.current_state = BattleManager.State.FORCED_TARGET
	scene.manager = manager
	scene.add_child(manager)
	scene.add_child(hero_area)
	scene.add_child(enemy_area)
	add_child_autofree(scene)
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
	event.device = SYNTHETIC_UNCONNECTED_JOY_DEVICE
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
	var second_enemy := preload("res://src/battle/enemy_card.tscn").instantiate() as EnemyCard
	second_enemy.name = "second_enemy"
	enemy.position = Vector2(100, 100)
	second_enemy.position = Vector2(300, 100)
	var hero_area := Control.new()
	var enemy_area := Control.new()
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	manager.current_actor = hero
	manager.forced_target = enemy
	hero.connect(&"target_hovered", Callable(manager, &"_on_target_hovered"))
	hero.connect(&"target_unhovered", Callable(manager, &"_on_target_unhovered"))
	enemy.connect(&"target_hovered", Callable(manager, &"_on_target_hovered"))
	enemy.connect(&"target_unhovered", Callable(manager, &"_on_target_unhovered"))
	second_enemy.connect(&"target_hovered", Callable(manager, &"_on_target_hovered"))
	second_enemy.connect(&"target_unhovered", Callable(manager, &"_on_target_unhovered"))
	scene.manager = manager
	scene.add_child(manager)
	scene.add_child(hero_area)
	scene.add_child(enemy_area)
	scene.add_child(bar)
	add_child_autofree(scene)
	await get_tree().process_frame
	hero_area.add_child(hero)
	enemy_area.add_child(enemy)
	enemy_area.add_child(second_enemy)
	await get_tree().process_frame
	CardSceneTestFixture.bind(
		self, hero, BattleCombatant.Faction.HERO, null, manager,
	)
	CardSceneTestFixture.bind(
		self, enemy, BattleCombatant.Faction.ENEMY, null, manager,
	)
	CardSceneTestFixture.bind(
		self, second_enemy, BattleCombatant.Faction.ENEMY, null, manager,
	)
	hero.is_defeated = false
	enemy.is_defeated = false
	second_enemy.is_defeated = false
	enemy.is_valid_target = false
	second_enemy.is_valid_target = false
	return {scene = scene, manager = manager, bar = bar, ux = ux, hero = hero, enemy = enemy, second_enemy = second_enemy}
