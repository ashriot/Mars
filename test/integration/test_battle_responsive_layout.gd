extends GutTest

const ResponsiveFixture = preload("res://test/fixtures/responsive_viewport_fixture.gd")
const BattleSceneResource = preload("res://src/battle/battle_scene.tscn")
const DECK_SIZE := Vector2i(1280, 800)


func after_each() -> void:
	for tween in get_tree().get_processed_tweens():
		tween.kill()


func test_compact_battle_composition_and_controls_fit_deck_output() -> void:
	var battle := await _battle_in_viewport(DECK_SIZE)
	var turn_queue := battle.get_node("UI/TurnQueue") as TurnQueue
	var action_bar := battle.get_node("UI/ActionBar") as ActionBar
	var action_button := action_bar.get_node("Actions/ActionButtonD") as ActionButton
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
		(action_bar.get_node("Actions/Passive/Header") as Label).get_theme_font_size(&"font_size"),
		24,
	)
	assert_eq(turn_queue.queue_items[0].enemy_label.get_theme_font_size(&"font_size"), 24)
	assert_gte(
		(action_bar.get_node("Actions/ActionButtonD/Title") as Label).get_theme_font_size(&"font_size"),
		30,
	)
	battle.apply_display_profile(
		DisplayProfileService.Profile.DESKTOP,
		Vector2i(1920, 1080),
		Vector2(1920, 1080),
	)
	assert_eq(turn_queue.queue_items[0].enemy_label.get_theme_font_size(&"font_size"), 20)
	enemy.free()


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
	var battle := BattleSceneResource.instantiate() as BattleScene
	viewport.add_child(battle)
	battle.apply_display_profile(
		DisplayProfileService.profile_for(window_size),
		window_size,
		viewport.size,
	)
	await get_tree().process_frame
	return battle


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
