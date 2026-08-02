extends GutTest


func test_high_focus_free_rule_beats_lower_priority_cooldown() -> void:
	var fixture := _fixture()
	fixture.echo.current_focus = 6
	var spike := _ability(&"spike", 0, 80, EnemyDecisionCondition.Type.ANY_HERO_FOCUS_AT_LEAST,
		EnemyTargetSelector.Type.HIGHEST_FOCUS_HERO, 5.0)
	var wave := _ability(&"wave", 4, 50, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.ALL_HEROES)
	var decision := EnemyDecisionEngine.choose(fixture.enemy, [spike, wave], fixture.state, fixture.context)
	assert_eq(decision.ability.ability_id, &"spike")
	assert_eq(decision.targets, [fixture.echo])
	_free_fixture(fixture)


func test_equal_priority_prefers_longer_cooldown_then_stable_seeded_target() -> void:
	var fixture := _fixture()
	var short := _ability(&"short", 2, 40, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.SEEDED_HERO)
	var long := _ability(&"long", 4, 40, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.SEEDED_HERO)
	var first := EnemyDecisionEngine.choose(fixture.enemy, [short, long], fixture.state, fixture.context)
	var second := EnemyDecisionEngine.choose(fixture.enemy, [short, long], fixture.state, fixture.context)
	assert_eq(first.ability.ability_id, &"long")
	assert_same(first.targets[0], second.targets[0])
	assert_eq(fixture.state.completed_turns, 0)
	_free_fixture(fixture)


func test_taunt_overrides_highest_focus_but_not_all_heroes() -> void:
	var fixture := _fixture()
	fixture.echo.current_focus = 10
	var conditions: Array[Condition] = [_taunt()]
	fixture.sands.active_conditions = conditions
	var single := _ability(&"single", 0, 0, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.HIGHEST_FOCUS_HERO)
	assert_eq(EnemyDecisionEngine.choose(fixture.enemy, [single], fixture.state, fixture.context).targets,
		[fixture.sands])
	var group := _ability(&"group", 0, 0, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.ALL_HEROES)
	assert_eq(EnemyDecisionEngine.choose(fixture.enemy, [group], fixture.state, fixture.context).targets,
		[fixture.sands, fixture.echo])
	_free_fixture(fixture)


func test_low_hp_percentage_selector_and_urgent_heal() -> void:
	var fixture := _fixture()
	fixture.ally.current_stats.max_hp = 1000
	fixture.ally.current_hp = 400
	fixture.enemy.current_stats.max_hp = 100
	fixture.enemy.current_hp = 60
	var heal := _ability(&"heal", 4, 100, EnemyDecisionCondition.Type.ANY_ALLY_HP_AT_MOST,
		EnemyTargetSelector.Type.LOWEST_HP_PERCENT_ALLY, 0.5)
	var attack := _ability(&"attack", 5, 90, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.SEEDED_HERO)
	var decision := EnemyDecisionEngine.choose(fixture.enemy, [heal, attack], fixture.state, fixture.context)
	assert_eq(decision.ability.ability_id, &"heal")
	assert_eq(decision.targets, [fixture.ally])
	_free_fixture(fixture)


func _fixture() -> Dictionary:
	var sands := _hero(100, 1, 0)
	var echo := _hero(100, 2, 0)
	var enemy := _enemy(100, 3, 2)
	var ally := _enemy(100, 4, 1)
	var heroes: Array[HeroCombatant] = [sands, echo]
	var enemies: Array[EnemyCombatant] = [enemy, ally]
	var ticks := {sands: 8, echo: 3, enemy: 6, ally: 12}
	var state := EnemyAIRuntimeState.new()
	return {
		"sands": sands,
		"echo": echo,
		"enemy": enemy,
		"ally": ally,
		"state": state,
		"context": EnemyAIContext.new(heroes, enemies, ticks, 1234),
	}


func _hero(max_hp: int, priority: int, guard: int) -> HeroCombatant:
	var hero := HeroCombatant.new()
	_initialize_actor(hero, max_hp, priority, guard)
	return hero


func _enemy(max_hp: int, priority: int, guard: int) -> EnemyCombatant:
	var enemy := EnemyCombatant.new()
	_initialize_actor(enemy, max_hp, priority, guard)
	return enemy


func _initialize_actor(
	actor: BattleCombatant,
	max_hp: int,
	priority: int,
	guard: int,
) -> void:
	var stats := ActorStats.new()
	stats.max_hp = max_hp
	actor.setup_base(
		stats,
		BattleCombatant.Faction.HERO if actor is HeroCombatant \
		else BattleCombatant.Faction.ENEMY,
	)
	actor.current_guard = guard
	actor.battle_priority = priority


func _ability(id: StringName, cooldown: int, priority: int,
	condition_type: EnemyDecisionCondition.Type, selector_type: EnemyTargetSelector.Type,
	threshold := 0.0) -> EnemyAbility:
	var condition := EnemyDecisionCondition.new()
	condition.type = condition_type
	condition.threshold = threshold
	var selector := EnemyTargetSelector.new()
	selector.type = selector_type
	var rule := EnemyDecisionRule.new()
	rule.priority = priority
	rule.conditions = [condition]
	rule.selector = selector
	rule.reason = "test rule"
	var ability := EnemyAbility.new()
	ability.ability_id = id
	ability.action = Action.new()
	ability.cooldown_turns = cooldown
	ability.rules = [rule]
	return ability


func _taunt() -> Condition:
	var condition := Condition.new()
	condition.condition_name = "Taunt"
	condition.is_taunting = true
	return condition


func _free_fixture(fixture: Dictionary) -> void:
	(fixture.enemy as EnemyCombatant).free()
	(fixture.ally as EnemyCombatant).free()
	(fixture.sands as HeroCombatant).free()
	(fixture.echo as HeroCombatant).free()
