extends GutTest


const HERO_SCENE := preload("res://src/battle/hero_card.tscn")


class RevivalBattleManager extends BattleManager:
	func wait(_duration: float = 0.01) -> void:
		return

	func _check_if_battle_ended() -> bool:
		return false

	func _update_all_enemy_intents() -> void:
		return


func test_defeated_hero_rejoins_projection_through_reviving_heal_once() -> void:
	var manager := RevivalBattleManager.new()
	var hero := HERO_SCENE.instantiate() as HeroCard
	var enemy := EnemyCard.new()
	var hero_stats := ActorStats.new()
	hero_stats.actor_name = "Revived Hero"
	hero_stats.max_hp = 100
	hero_stats.psyche = 20
	hero_stats.speed = 100
	var enemy_stats := ActorStats.new()
	enemy_stats.speed = 100
	hero.current_stats = hero_stats
	hero.current_hp = 0
	hero.hero_data = HeroData.new()
	hero.actor_name = hero_stats.actor_name
	hero.battle_manager = manager
	hero.battle_priority = 0
	enemy.current_stats = enemy_stats
	enemy.battle_priority = 1
	manager.actor_list = [hero, enemy]
	manager.battle_ct_speed_scale = 0.75
	hero.ct_speed_scale = 3.0
	add_child_autofree(hero)
	await get_tree().process_frame
	hero.actor_defeated.connect(manager._on_actor_died)
	assert_true(hero.has_signal("actor_revived"), "production heroes expose a revival seam")
	if hero.has_signal("actor_revived"):
		hero.connect("actor_revived", manager._on_actor_revived)
	var published_queues := {count = 0}
	manager.turn_order_updated.connect(
		func(_queue: Array, _kind: BattleManager.TurnOrderUpdate) -> void:
			published_queues.count += 1
	)

	hero.defeated()
	await get_tree().process_frame
	assert_does_not_have(manager.actor_list, hero)
	var queues_after_death: int = published_queues.count
	var stable_priority := hero.battle_priority
	var heal := Effect_Healing.new()
	heal.potency = 1.0
	heal.is_revive = true

	await heal.execute(hero, [hero], manager)

	assert_false(hero.is_defeated)
	assert_eq(manager.actor_list.count(hero), 1)
	assert_eq(hero.ct_speed_scale, manager.battle_ct_speed_scale)
	assert_eq(hero.battle_priority, stable_priority)
	assert_eq(published_queues.count, queues_after_death + 1, "revival publishes the refreshed queue once")
	assert_has(
		manager._run_ct_simulation(4).map(func(entry: Dictionary): return entry.actor),
		hero,
		"revived hero can receive a future turn",
	)
	var queues_after_revive: int = published_queues.count
	await heal.execute(hero, [hero], manager)
	assert_eq(manager.actor_list.count(hero), 1, "ordinary healing cannot duplicate roster entry")
	assert_eq(published_queues.count, queues_after_revive, "ordinary healing does not publish a revival queue")

	manager.free()
	enemy.free()
