extends GutTest

const DRAW_FIRE := preload("res://data/heroes/sands/conditions/draw_fire.tres")


func test_draw_fire_is_taunt_not_untargetable_and_expires_on_shift_or_breach() -> void:
	assert_true(DRAW_FIRE.is_taunting)
	assert_false(DRAW_FIRE.is_untargetable)
	assert_has(DRAW_FIRE.remove_on_triggers, Trigger.TriggerType.ON_SHIFT)
	assert_has(DRAW_FIRE.remove_on_triggers, Trigger.TriggerType.ON_BREACHED)
	assert_does_not_have(DRAW_FIRE.remove_on_triggers, Trigger.TriggerType.ON_HEALED)


func test_draw_fire_restricts_direct_single_target_to_sands() -> void:
	var fixture := _fixture()
	var conditions: Array[Condition] = [DRAW_FIRE.duplicate(true) as Condition]
	fixture.sands.active_conditions = conditions
	var selector := EnemyTargetSelector.new()
	selector.type = EnemyTargetSelector.Type.SEEDED_HERO

	assert_eq(selector.select(fixture.enemy, fixture.state, fixture.context, "direct"), [fixture.sands])
	_free_fixture(fixture)


func test_draw_fire_restricts_random_enemy_candidates_to_sands() -> void:
	var fixture := _fixture()
	var conditions: Array[Condition] = [DRAW_FIRE.duplicate(true) as Condition]
	fixture.sands.active_conditions = conditions
	var selector := EnemyTargetSelector.new()
	selector.type = EnemyTargetSelector.Type.VALID_HERO_CANDIDATES

	assert_eq(selector.select(fixture.enemy, fixture.state, fixture.context, "random"), [fixture.sands])
	_free_fixture(fixture)


func test_draw_fire_does_not_change_all_enemy_targets() -> void:
	var fixture := _fixture()
	var conditions: Array[Condition] = [DRAW_FIRE.duplicate(true) as Condition]
	fixture.sands.active_conditions = conditions
	var selector := EnemyTargetSelector.new()
	selector.type = EnemyTargetSelector.Type.ALL_HEROES

	assert_eq(selector.select(fixture.enemy, fixture.state, fixture.context, "group"), [fixture.sands, fixture.other])
	_free_fixture(fixture)


func test_untargetable_hero_is_excluded_from_single_and_group_selectors() -> void:
	var fixture := _fixture()
	var hidden := Condition.new()
	hidden.condition_name = "Hidden"
	hidden.is_untargetable = true
	var conditions: Array[Condition] = [hidden]
	fixture.other.active_conditions = conditions
	var single := EnemyTargetSelector.new()
	single.type = EnemyTargetSelector.Type.SEEDED_HERO
	var group := EnemyTargetSelector.new()
	group.type = EnemyTargetSelector.Type.ALL_HEROES

	assert_eq(single.select(fixture.enemy, fixture.state, fixture.context, "single"), [fixture.sands])
	assert_eq(group.select(fixture.enemy, fixture.state, fixture.context, "group"), [fixture.sands])
	_free_fixture(fixture)


func _fixture() -> Dictionary:
	var sands := HeroCombatant.new()
	var other := HeroCombatant.new()
	var enemy := EnemyCombatant.new()
	sands.setup_base(ActorStats.new(), BattleCombatant.Faction.HERO)
	other.setup_base(ActorStats.new(), BattleCombatant.Faction.HERO)
	enemy.setup_base(ActorStats.new(), BattleCombatant.Faction.ENEMY)
	sands.actor_name = "Sands"
	other.actor_name = "Asher"
	sands.battle_priority = 0
	other.battle_priority = 1
	enemy.battle_priority = 2
	var heroes: Array[HeroCombatant] = [sands, other]
	var enemies: Array[EnemyCombatant] = [enemy]
	return {
		"sands": sands,
		"other": other,
		"enemy": enemy,
		"state": EnemyAIRuntimeState.new(),
		"context": EnemyAIContext.new(heroes, enemies, {}, 1234),
	}


func _free_fixture(fixture: Dictionary) -> void:
	(fixture.enemy as EnemyCombatant).free()
	(fixture.sands as HeroCombatant).free()
	(fixture.other as HeroCombatant).free()
