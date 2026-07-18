extends GutTest

const DRAW_FIRE := preload("res://data/heroes/sands/conditions/draw_fire.tres")


class QuietHero extends HeroCard:
	func _update_conditions_ui() -> void:
		return


class QuietEnemy extends EnemyCard:
	func _update_intent_ui() -> void:
		return


class TargetingManager extends BattleManager:
	var heroes: Array[HeroCard] = []
	var enemies: Array[EnemyCard] = []

	func get_living_heroes() -> Array[HeroCard]:
		return heroes

	func get_living_enemies() -> Array[EnemyCard]:
		return enemies

	func update_turn_order() -> void:
		return


func test_draw_fire_is_taunt_not_untargetable_and_expires_on_shift_or_breach() -> void:
	assert_true(DRAW_FIRE.is_taunting)
	assert_false(DRAW_FIRE.is_untargetable)
	assert_has(DRAW_FIRE.remove_on_triggers, Trigger.TriggerType.ON_SHIFT)
	assert_has(DRAW_FIRE.remove_on_triggers, Trigger.TriggerType.ON_BREACHED)
	assert_does_not_have(DRAW_FIRE.remove_on_triggers, Trigger.TriggerType.ON_HEALED)


func test_applying_draw_fire_immediately_retargets_existing_single_target_intent() -> void:
	var fixture := _fixture(Action.TargetType.ONE_ENEMY)
	var manager := fixture.manager as TargetingManager
	var sands := fixture.sands as QuietHero
	var other := fixture.other as QuietHero
	var enemy := fixture.enemy as QuietEnemy
	var existing_targets: Array[ActorCard] = [other]
	enemy.intended_targets = existing_targets
	sands.actor_conditions_changed.connect(manager._on_actor_conditions_changed)

	await sands.add_condition(DRAW_FIRE)

	assert_eq(enemy.intended_targets, [sands])
	_free_fixture(fixture)


func test_draw_fire_restricts_random_enemy_candidates_to_sands() -> void:
	var fixture := _fixture(Action.TargetType.RANDOM_ENEMY)
	var manager := fixture.manager as TargetingManager
	var sands := fixture.sands as QuietHero
	var enemy := fixture.enemy as QuietEnemy
	var conditions: Array[Condition] = [DRAW_FIRE.duplicate(true) as Condition]
	sands.active_conditions = conditions

	enemy.get_a_target(manager.heroes)

	assert_eq(enemy.intended_targets, [sands])
	_free_fixture(fixture)


func test_draw_fire_does_not_change_all_enemy_targets() -> void:
	var fixture := _fixture(Action.TargetType.ALL_ENEMIES)
	var manager := fixture.manager as TargetingManager
	var sands := fixture.sands as QuietHero
	var other := fixture.other as QuietHero
	var enemy := fixture.enemy as QuietEnemy
	var conditions: Array[Condition] = [DRAW_FIRE.duplicate(true) as Condition]
	sands.active_conditions = conditions

	enemy.get_a_target(manager.heroes)

	assert_eq(enemy.intended_targets, [sands, other])
	_free_fixture(fixture)


func _fixture(target_type: Action.TargetType) -> Dictionary:
	var manager := TargetingManager.new()
	var sands := QuietHero.new()
	var other := QuietHero.new()
	var enemy := QuietEnemy.new()
	var action := Action.new()
	action.target_type = target_type
	sands.actor_name = "Sands"
	other.actor_name = "Asher"
	sands.add_to_group("player")
	other.add_to_group("player")
	manager.heroes = [sands, other]
	manager.enemies = [enemy]
	enemy.battle_manager = manager
	enemy.enemy_data = EnemyData.new()
	enemy.base_turn_action = action
	enemy.intended_action = action
	return {
		"manager": manager,
		"sands": sands,
		"other": other,
		"enemy": enemy,
		"action": action,
	}


func _free_fixture(fixture: Dictionary) -> void:
	(fixture.enemy as EnemyCard).free()
	(fixture.sands as HeroCard).free()
	(fixture.other as HeroCard).free()
	(fixture.manager as BattleManager).free()
