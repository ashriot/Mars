extends GutTest


const HERO_SCENE := preload("res://src/battle/hero_card.tscn")


class RevivalBattleManager extends BattleManager:
	func _ready() -> void:
		pass

	func wait(_duration: float = 0.01) -> void:
		return

	func _check_if_battle_ended() -> bool:
		return false

	func _update_all_enemy_intents() -> void:
		return


func test_revive_flag_controls_defeated_ally_targeting() -> void:
	var fixture := await _targeting_fixture()
	var manager: BattleManager = fixture.manager
	var scene: BattleScene = fixture.scene
	var defeated: HeroCard = fixture.defeated
	var healing := Effect_Healing.new()
	healing.is_revive = true
	var action := Action.new()
	action.target_type = Action.TargetType.ONE_ALLY
	action.effects = [healing]

	manager.set_current_action(action)

	assert_true(defeated.is_valid_target, "reviving actions expose defeated allies to pointer targeting")
	assert_has(scene._valid_targets(), defeated, "reviving actions expose defeated allies to controller targeting")

	manager._clear_all_targeting_ui()
	healing.is_revive = false
	manager.set_current_action(action)
	assert_false(defeated.is_valid_target, "ordinary healing cannot target defeated allies")


func test_non_revive_enemy_heal_ignores_defeated_target() -> void:
	var manager := RevivalBattleManager.new()
	var attacker := EnemyCard.new()
	attacker.current_stats = ActorStats.new()
	attacker.current_stats.psyche = 20
	var target := EnemyCard.new()
	target.current_stats = ActorStats.new()
	target.current_stats.max_hp = 100
	target.current_hp = 0
	target.is_defeated = true
	var effect := Effect_Healing.new()
	effect.potency = 2.0
	effect.is_revive = false

	await effect.execute(attacker, [target], manager)

	assert_eq(target.current_hp, 0)
	assert_true(target.is_defeated)
	manager.free()
	attacker.free()
	target.free()


func test_defeated_card_finishes_delayed_damage_bar_after_leaving_actor_list() -> void:
	var manager := RevivalBattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	manager.battle_speed = 100.0
	manager.add_child(hero_area)
	manager.add_child(enemy_area)
	add_child_autofree(manager)
	var hero := HERO_SCENE.instantiate() as HeroCard
	hero_area.add_child(hero)
	await get_tree().process_frame
	hero.battle_manager = manager
	hero.current_stats = _hero_stats("Defeated Hero")
	hero.current_hp = 0
	hero.is_defeated = true
	hero.hp_bar_actual.max_value = hero.current_stats.max_hp
	hero.hp_bar_ghost.max_value = hero.current_stats.max_hp
	hero.hp_bar_actual.value = 0
	hero.hp_bar_ghost.value = hero.current_stats.max_hp
	manager.actor_list = []

	await manager._flush_all_health_animations()

	assert_eq(hero.hp_bar_ghost.value, 0.0, "lethal damage drains the delayed yellow bar to zero")


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


func _targeting_fixture() -> Dictionary:
	var scene := BattleScene.new()
	var manager := RevivalBattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	var action_panel := _action_panel()
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	manager.current_action_panel = action_panel
	manager.add_child(hero_area)
	manager.add_child(enemy_area)
	manager.add_child(action_panel)
	scene.manager = manager
	scene.add_child(manager)
	add_child_autofree(scene)

	var healer := HERO_SCENE.instantiate() as HeroCard
	var defeated := HERO_SCENE.instantiate() as HeroCard
	healer.current_stats = _hero_stats("Healer")
	defeated.current_stats = _hero_stats("Defeated Ally")
	healer.actor_name = "Healer"
	defeated.actor_name = "Defeated Ally"
	healer.is_defeated = false
	defeated.is_defeated = true
	healer.battle_manager = manager
	defeated.battle_manager = manager
	var role_definition := RoleDefinition.new()
	role_definition.color = Color.WHITE
	var role := RoleData.new()
	role.source_definition = role_definition
	healer.loaded_roles = [role]
	healer.current_role_index = 0
	hero_area.add_child(healer)
	hero_area.add_child(defeated)
	manager.current_actor = healer
	manager.actor_list = [healer]
	await get_tree().process_frame
	return {scene = scene, manager = manager, healer = healer, defeated = defeated}


func _action_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.name = "HBoxContainer"
	panel.add_child(row)
	var mask := Control.new()
	mask.name = "Mask"
	row.add_child(mask)
	var icon := TextureRect.new()
	icon.name = "Icon"
	mask.add_child(icon)
	var ct_percent := Label.new()
	ct_percent.name = "CTPercent"
	row.add_child(ct_percent)
	var description := RichTextLabel.new()
	description.name = "Label"
	row.add_child(description)
	return panel


func _hero_stats(actor_name: String) -> ActorStats:
	var stats := ActorStats.new()
	stats.actor_name = actor_name
	stats.max_hp = 100
	stats.psyche = 20
	stats.speed = 100
	return stats
