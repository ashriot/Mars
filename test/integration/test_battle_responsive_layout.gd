extends GutTest

const CardTestFactory := preload("res://test/helpers/card_test_factory.gd")


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


func _enemy(actor_name: String) -> EnemyCard:
	var actor := CardTestFactory.enemy()
	actor.actor_name = actor_name
	return actor
