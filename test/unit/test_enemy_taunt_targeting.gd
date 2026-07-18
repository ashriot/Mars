extends GutTest

const DRAW_FIRE := preload("res://data/heroes/sands/conditions/draw_fire.tres")


class QuietHero extends HeroCard:
	func _update_conditions_ui() -> void:
		return


class QuietEnemy extends EnemyCard:
	func _update_intent_ui() -> void:
		return


func test_draw_fire_is_taunt_not_untargetable_and_expires_on_shift_or_breach() -> void:
	assert_true(DRAW_FIRE.is_taunting)
	assert_false(DRAW_FIRE.is_untargetable)
	assert_has(DRAW_FIRE.remove_on_triggers, Trigger.TriggerType.ON_SHIFT)
	assert_has(DRAW_FIRE.remove_on_triggers, Trigger.TriggerType.ON_BREACHED)
	assert_does_not_have(DRAW_FIRE.remove_on_triggers, Trigger.TriggerType.ON_HEALED)


func test_draw_fire_restricts_direct_single_target_to_sands() -> void:
	var fixture := _fixture()
	var sands := fixture.sands as QuietHero
	var conditions: Array[Condition] = [DRAW_FIRE.duplicate(true) as Condition]
	sands.active_conditions = conditions
	var selector := EnemyTargetSelector.new()
	selector.type = EnemyTargetSelector.Type.SEEDED_HERO

	assert_eq(selector.select(fixture.enemy, fixture.state, fixture.context, "direct"), [sands])
	_free_fixture(fixture)


func test_draw_fire_restricts_random_enemy_candidates_to_sands() -> void:
	var fixture := _fixture()
	var sands := fixture.sands as QuietHero
	var conditions: Array[Condition] = [DRAW_FIRE.duplicate(true) as Condition]
	sands.active_conditions = conditions
	var selector := EnemyTargetSelector.new()
	selector.type = EnemyTargetSelector.Type.VALID_HERO_CANDIDATES

	assert_eq(selector.select(fixture.enemy, fixture.state, fixture.context, "random"), [sands])
	_free_fixture(fixture)


func test_draw_fire_does_not_change_all_enemy_targets() -> void:
	var fixture := _fixture()
	var sands := fixture.sands as QuietHero
	var other := fixture.other as QuietHero
	var conditions: Array[Condition] = [DRAW_FIRE.duplicate(true) as Condition]
	sands.active_conditions = conditions
	var selector := EnemyTargetSelector.new()
	selector.type = EnemyTargetSelector.Type.ALL_HEROES

	assert_eq(selector.select(fixture.enemy, fixture.state, fixture.context, "group"), [sands, other])
	_free_fixture(fixture)


func test_untargetable_hero_is_excluded_from_single_and_group_selectors() -> void:
	var fixture := _fixture()
	var other := fixture.other as QuietHero
	var hidden := Condition.new()
	hidden.condition_name = "Hidden"
	hidden.is_untargetable = true
	var conditions: Array[Condition] = [hidden]
	other.active_conditions = conditions
	var single := EnemyTargetSelector.new()
	single.type = EnemyTargetSelector.Type.SEEDED_HERO
	var group := EnemyTargetSelector.new()
	group.type = EnemyTargetSelector.Type.ALL_HEROES

	assert_eq(single.select(fixture.enemy, fixture.state, fixture.context, "single"), [fixture.sands])
	assert_eq(group.select(fixture.enemy, fixture.state, fixture.context, "group"), [fixture.sands])
	_free_fixture(fixture)


func _fixture() -> Dictionary:
	var sands := QuietHero.new()
	var other := QuietHero.new()
	var enemy := QuietEnemy.new()
	sands.actor_name = "Sands"
	other.actor_name = "Asher"
	sands.battle_priority = 0
	other.battle_priority = 1
	enemy.battle_priority = 2
	var heroes: Array[HeroCard] = [sands, other]
	var enemies: Array[EnemyCard] = [enemy]
	return {
		"sands": sands,
		"other": other,
		"enemy": enemy,
		"state": EnemyAIRuntimeState.new(),
		"context": EnemyAIContext.new(heroes, enemies, {}, 1234),
	}


func _free_fixture(fixture: Dictionary) -> void:
	(fixture.enemy as EnemyCard).free()
	(fixture.sands as HeroCard).free()
	(fixture.other as HeroCard).free()
