extends GutTest

const ResponsiveFixture = preload("res://test/fixtures/responsive_viewport_fixture.gd")
const BattleSceneResource = preload("res://src/battle/battle_scene.tscn")
const GameManagerResource = preload("res://src/battle/game_manager.tscn")
const DECK_SIZE := Vector2i(1280, 800)


func after_each() -> void:
	for tween in get_tree().get_processed_tweens():
		tween.kill()


func test_compact_battle_composition_and_controls_fit_deck_output() -> void:
	var battle := await _battle_in_viewport(DECK_SIZE)
	var turn_queue := battle.get_node("UI/TurnQueue") as TurnQueue
	var action_bar := battle.get_node("UI/ActionBar") as ActionBar
	var action_button := action_bar.get_node("BottomRow/Actions/ActionButtonD") as ActionButton
	var enemy := _enemy("Attack Drone A")
	turn_queue._on_turn_order_updated([
		{"actor": enemy, "ticks_needed": 0},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame

	for path in ["UI/TurnQueue", "UI/ActionBar", "UI/Heroes", "UI/Enemies"]:
		assert_true(
			ResponsiveFixture.fits_output(battle.get_node(path), DECK_SIZE),
			"%s must fit the Deck output" % path,
		)
	var queue_size := ResponsiveFixture.physical_rect(turn_queue.queue_items[0], DECK_SIZE).size
	assert_gte(queue_size.x, 48.0)
	assert_gte(queue_size.y, 48.0)
	assert_gte(ResponsiveFixture.physical_rect(action_button, DECK_SIZE).size.y, 48.0)
	assert_lt(
		(battle.get_node("UI/CurrentAction") as Control).get_global_rect().end.x,
		turn_queue.get_global_rect().position.x,
	)
	enemy.free()


func test_compact_battle_metadata_remains_readable_at_deck_scale() -> void:
	var battle := await _battle_in_viewport(DECK_SIZE)
	var action_bar := battle.get_node("UI/ActionBar") as ActionBar
	var turn_queue := battle.get_node("UI/TurnQueue") as TurnQueue
	var enemy := _enemy("Attack Drone A")
	turn_queue._on_turn_order_updated([
		{"actor": enemy, "ticks_needed": 0},
	], BattleManager.TurnOrderUpdate.REFRESH)
	await get_tree().process_frame

	assert_eq(
		(action_bar.get_node("TopRow/Passive/Header") as Label).get_theme_font_size(&"font_size"),
		24,
	)
	assert_eq(turn_queue.queue_items[0].enemy_label.get_theme_font_size(&"font_size"), 24)
	assert_gte(
		(action_bar.get_node("BottomRow/Actions/ActionButtonD/Title") as Label).get_theme_font_size(&"font_size"),
		24,
	)
	battle.apply_display_profile(
		DisplayProfileService.Profile.DESKTOP,
		Vector2i(1920, 1080),
		Vector2(1920, 1080),
	)
	assert_eq(turn_queue.queue_items[0].enemy_label.get_theme_font_size(&"font_size"), 20)
	enemy.free()


func test_packed_action_bar_uses_ordered_top_and_bottom_containers() -> void:
	var battle := await _battle_in_viewport(Vector2i(1920, 1080))
	var action_bar := battle.get_node("UI/ActionBar") as ActionBar
	var top_row := action_bar.get_node_or_null("TopRow") as HBoxContainer
	var bottom_row := action_bar.get_node_or_null("BottomRow") as HBoxContainer
	assert_not_null(top_row)
	assert_not_null(bottom_row)
	if top_row == null or bottom_row == null:
		return

	assert_same(action_bar.passive_panel.get_parent(), top_row)
	assert_same(action_bar.shift_action_panel.get_parent(), top_row)
	assert_same(action_bar.left_shift_ui.get_parent(), bottom_row)
	assert_same(action_bar.right_shift_ui.get_parent(), bottom_row)
	assert_same(action_bar.actions_ui.get_parent(), bottom_row)
	assert_eq(action_bar.actions_ui.get_child_count(), 4)
	var expected_names := [
		&"ActionButtonD",
		&"ActionButtonR",
		&"ActionButtonL",
		&"ActionButtonU",
	]
	for index in 4:
		var action_button := action_bar.actions_ui.get_child(index) as ActionButton
		assert_eq(action_button.name, expected_names[index])
		assert_eq(action_button.glyph_action, StringName("action_%d" % (index + 1)))
	assert_eq(
		(action_bar.right_shift_ui.get_node("DynamicGlyph") as DynamicGlyph).action,
		&"shift_right",
	)
	assert_eq(action_bar.left_shift_ui.custom_minimum_size, Vector2(220.0, 70.0))
	assert_eq(action_bar.right_shift_ui.custom_minimum_size, Vector2(220.0, 70.0))
	for action_button in action_bar.actions_ui.get_children():
		assert_eq((action_button as ActionButton).custom_minimum_size, Vector2(270.0, 100.0))


func test_right_shift_glyph_is_reserved_by_layout_and_clears_action_buttons() -> void:
	var battle := await _battle_in_viewport(Vector2i(1920, 1080))
	var action_bar := battle.get_node("UI/ActionBar") as ActionBar
	var bottom_row := action_bar.bottom_row
	var actions := action_bar.actions_ui
	var right_shift := action_bar.right_shift_ui
	var glyph := right_shift.get_node("DynamicGlyph") as DynamicGlyph
	var actions_index := actions.get_index()
	var right_shift_index := right_shift.get_index()
	var reserved_rect := right_shift.get_global_rect()

	for sibling_index in range(actions_index + 1, right_shift_index):
		var sibling := bottom_row.get_child(sibling_index) as Control
		if sibling != null:
			reserved_rect = reserved_rect.merge(sibling.get_global_rect())

	var glyph_rect := glyph.get_global_rect()
	assert_true(
		reserved_rect.encloses(glyph_rect),
		"the container layout reserves the right-shift glyph's complete visual footprint",
	)
	for action_button: ActionButton in actions.get_children():
		assert_false(
			glyph_rect.intersects(action_button.get_global_rect()),
			"the right-shift glyph must not cover %s" % action_button.name,
		)


func test_action_bar_rows_animate_without_changing_container_owned_geometry() -> void:
	var battle := await _battle_in_viewport(Vector2i(1920, 1080))
	var action_bar := battle.get_node("UI/ActionBar") as ActionBar
	await action_bar.slide_in(0.0)
	var top_child_positions := _child_positions(action_bar.top_row)
	var bottom_child_positions := _child_positions(action_bar.bottom_row)

	await action_bar.slide_out(0.0)

	assert_eq(_child_positions(action_bar.top_row), top_child_positions)
	assert_eq(_child_positions(action_bar.bottom_row), bottom_child_positions)
	assert_eq(action_bar.top_row.modulate.a, 0.0)
	assert_eq(action_bar.bottom_row.modulate.a, 0.0)

	await action_bar.slide_in(0.0)

	assert_eq(action_bar.top_row.position, action_bar.top_row_on_screen_pos)
	assert_eq(action_bar.bottom_row.position, action_bar.bottom_row_on_screen_pos)
	assert_eq(_child_positions(action_bar.top_row), top_child_positions)
	assert_eq(_child_positions(action_bar.bottom_row), bottom_child_positions)
	assert_eq(action_bar.top_row.modulate.a, 1.0)
	assert_eq(action_bar.bottom_row.modulate.a, 1.0)


func test_battle_scene_world_replaces_only_legacy_enemy_lane_and_backdrop() -> void:
	var battle := await _battle_in_viewport(DECK_SIZE)
	var world := battle.get_node_or_null("BattleWorld3D") as BattleWorld3D

	assert_not_null(world)
	assert_same(battle.manager.battle_world, world)
	assert_lt(world.get_index(), battle.get_node("UI").get_index())
	assert_eq(
		battle.manager.hero_view_scene.resource_path,
		"res://src/battle/hero_card.tscn",
	)
	assert_eq(
		battle.manager.enemy_view_scene.resource_path,
		"res://src/battle/presentation/enemy_drone_presentation.tscn",
	)
	assert_false(battle.get_node("UI/Backdrop").visible)
	assert_false(battle.get_node("UI/Enemies/HBox").visible)
	assert_true(battle.get_node("UI/Heroes/HBox").visible)
	assert_true(world.hud_layer.visible)


func test_enemy_hud_canvas_is_effectively_between_world_and_player_ui() -> void:
	var battle := await _battle_in_viewport(DECK_SIZE)
	var world := battle.manager.battle_world
	var enemy_hud_canvas := world.get_node("EnemyHUDCanvas") as CanvasLayer
	var enemy_hud_layer := _effective_canvas_layer(world.hud_layer)
	var player_ui_layer := _effective_canvas_layer(battle.get_node("UI"))

	assert_same(world.hud_layer.get_parent(), enemy_hud_canvas)
	assert_eq(enemy_hud_layer, enemy_hud_canvas.layer)
	assert_lt(enemy_hud_layer, player_ui_layer)
	assert_true(world.hud_layer.visible, "enemy HUD remains a canvas overlay above 3D")


func test_battle_hud_canvases_draw_in_front_of_the_3d_environment() -> void:
	# Battles are normally parented by GameManager's OverlayLayer. Exercise
	# that real ancestry so the test guards the canvas-layer ordering players
	# see, rather than the isolated BattleScene fixture's fallback layer.
	var game := GameManagerResource.instantiate() as GameManager
	var battle := BattleSceneResource.instantiate() as BattleScene
	var overlay := game.get_node("DungeonMap/OverlayLayer") as CanvasLayer
	overlay.add_child(battle)

	var world := battle.get_node("BattleWorld3D") as BattleWorld3D
	var enemy_hud_canvas := world.get_node("EnemyHUDCanvas") as CanvasLayer
	var projectile_canvas := world.get_node("BattleProjectileLayer") as CanvasLayer
	var player_ui_layer := _effective_canvas_layer(battle.get_node("UI"))

	# GameManager must not own a WorldEnvironment: a second WorldEnvironment
	# would silently win over the battle camera's canvas-background split and
	# previously left the arena unlit with the projected HUDs swallowed.
	assert_null(
		game.get_node_or_null("WorldEnvironment"),
		"GameManager must not compete with the battle camera's environment",
	)
	var camera := world.get_node("CameraRig/BattleCamera") as Camera3D
	var camera_environment := camera.environment
	assert_not_null(
		camera_environment,
		"the battle camera carries the arena environment so it applies in-game",
	)
	assert_eq(
		camera_environment.background_mode,
		Environment.BG_COLOR,
		"the arena paints an opaque backdrop; the dungeon map hides during battle",
	)
	assert_gt(
		enemy_hud_canvas.layer,
		0,
		"the projected enemy HUD must draw in front of the 3D environment",
	)
	assert_eq(projectile_canvas.layer, enemy_hud_canvas.layer)
	assert_lt(
		enemy_hud_canvas.layer,
		player_ui_layer,
		"essential player UI must draw above projected enemy HUDs and projectiles",
	)
	game.free()


func test_packed_battle_projectiles_draw_above_enemy_plane_but_below_player_ui() -> void:
	var battle := await _battle_in_viewport(DECK_SIZE)
	var world := battle.manager.battle_world
	var enemy_hud_canvas := world.get_node("EnemyHUDCanvas") as CanvasLayer
	var projectile_canvas := world.projectile_layer
	var player_ui := battle.get_node("UI") as Control

	assert_eq(_effective_canvas_layer(projectile_canvas), enemy_hud_canvas.layer)
	assert_gt(
		projectile_canvas.get_index(),
		enemy_hud_canvas.get_index(),
		"same-layer projectiles draw after the projected enemy plane",
	)
	assert_lt(
		_effective_canvas_layer(projectile_canvas),
		_effective_canvas_layer(player_ui),
		"essential hero, action, and CTB UI draws after projectiles",
	)
	assert_eq(
		projectile_canvas.effect_root.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
	)


func test_runtime_world_visibility_switches_fallbacks_and_projected_hud_together() -> void:
	var battle := await _battle_in_viewport(DECK_SIZE)
	var world := battle.manager.battle_world

	world.hide()
	await get_tree().process_frame

	assert_true(battle.get_node("UI/Backdrop").visible)
	assert_true(battle.get_node("UI/Enemies/HBox").visible)
	assert_false(world.hud_layer.visible)

	world.show()
	await get_tree().process_frame

	assert_false(battle.get_node("UI/Backdrop").visible)
	assert_false(battle.get_node("UI/Enemies/HBox").visible)
	assert_true(world.hud_layer.visible)


func test_runtime_world_removal_and_readdition_switches_the_same_layers() -> void:
	var battle := await _battle_in_viewport(DECK_SIZE)
	var world := battle.manager.battle_world

	battle.remove_child(world)
	await get_tree().process_frame

	assert_true(battle.get_node("UI/Backdrop").visible)
	assert_true(battle.get_node("UI/Enemies/HBox").visible)
	assert_false(world.hud_layer.visible)

	battle.add_child(world)
	await get_tree().process_frame

	assert_false(battle.get_node("UI/Backdrop").visible)
	assert_false(battle.get_node("UI/Enemies/HBox").visible)
	assert_true(world.hud_layer.visible)


func test_battle_scene_without_world_restores_legacy_visual_fallbacks() -> void:
	var viewport := SubViewport.new()
	viewport.size = DECK_SIZE
	add_child_autofree(viewport)
	var battle := BattleSceneResource.instantiate() as BattleScene
	var world := battle.get_node("BattleWorld3D") as BattleWorld3D
	battle.remove_child(world)
	world.free()
	battle.manager.battle_world = null
	viewport.add_child(battle)
	await get_tree().process_frame

	assert_true(battle.get_node("UI/Backdrop").visible)
	assert_true(battle.get_node("UI/Enemies/HBox").visible)
	assert_true(battle.get_node("UI/Heroes/HBox").visible)


func test_five_projected_enemy_huds_stay_inside_1280_by_800_safe_output() -> void:
	await _assert_five_projected_enemy_huds_fit(DECK_SIZE)


func test_five_projected_enemy_huds_stay_inside_1920_by_1080_safe_output() -> void:
	await _assert_five_projected_enemy_huds_fit(Vector2i(1920, 1080))


func _battle_in_viewport(window_size: Vector2i) -> BattleScene:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ResponsiveFixture.logical_size_for(window_size))
	add_child_autofree(viewport)
	var overlay := CanvasLayer.new()
	overlay.layer = 4
	viewport.add_child(overlay)
	var battle := BattleSceneResource.instantiate() as BattleScene
	overlay.add_child(battle)
	battle.apply_display_profile(
		DisplayProfileService.profile_for(window_size),
		window_size,
		viewport.size,
	)
	await get_tree().process_frame
	return battle


func _child_positions(container: Container) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for child in container.get_children():
		if child is Control:
			positions.append((child as Control).position)
	return positions


func _assert_five_projected_enemy_huds_fit(window_size: Vector2i) -> void:
	var battle := await _battle_in_viewport(window_size)
	var manager := battle.manager
	var world := manager.battle_world
	var presentations: Array[EnemyDronePresentation] = []
	for index in 5:
		var enemy := _enemy("Safe Drone %d" % index)
		manager.combatant_root.add_child(enemy)
		manager.actor_list.append(enemy)
		var presentation := manager._spawn_presentation_view(
			manager.enemy_view_scene,
			world.enemy_views,
			enemy,
		) as EnemyDronePresentation
		assert_not_null(presentation)
		var view_root := manager.presentation_view_root_for(enemy) as Node3D
		assert_true(world.place_ordinary_view(
			view_root, index, 5, BattleFormationLayout.Layout.W,
		))
		presentation._process(0.0)
		presentations.append(presentation)
	await get_tree().process_frame
	world._layout_enemy_huds()

	assert_eq(world.hud_layer.get_child_count(), 5)
	for presentation: EnemyDronePresentation in presentations:
		assert_true(presentation.is_target_visible())
		assert_true(presentation.hud.visible)
		assert_true(
			ResponsiveFixture.fits_output(presentation.hud, window_size),
			"every projected HUD fits the %dx%d output" % [
				window_size.x, window_size.y,
			],
		)


func _effective_canvas_layer(node: Node) -> int:
	var current := node
	while current != null:
		if current is CanvasLayer:
			return (current as CanvasLayer).layer
		current = current.get_parent()
	return 0


func _enemy(actor_name: String) -> EnemyCombatant:
	var stats := ActorStats.new()
	stats.actor_name = actor_name
	stats.max_hp = 100
	stats.speed = 10
	var actor := EnemyCombatant.new()
	actor.setup_base(stats, BattleCombatant.Faction.ENEMY)
	return actor
