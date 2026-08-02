extends GutTest


func _hero_data_with_three_roles() -> HeroData:
	var data := HeroData.new()
	data.hero_name = "Test Hero"
	data.derived_state_is_prebuilt = true
	data.stats = ActorStats.new()
	data.stats.actor_name = data.hero_name
	data.stats.max_hp = 100
	data.stats.starting_focus = 5
	for role_id: String in ["a", "b", "c"]:
		var definition := RoleDefinition.new()
		definition.role_id = role_id
		definition.role_name = role_id.to_upper()
		var role := RoleData.new()
		role.source_definition = definition
		data.role_definitions.append(definition)
		data.unlocked_role_ids.append(role_id)
		data.battle_roles[role_id] = role
	return data


func test_enemy_locks_intent_against_hero_combatants() -> void:
	var hero := HeroCombatant.new()
	add_child_autofree(hero)
	var hero_data := _hero_data_with_three_roles()
	hero.setup(hero_data)
	var enemy := EnemyCombatant.new()
	add_child_autofree(enemy)
	var enemy_data := preload(
		"res://data/enemies/actors/attack_drone.tres"
	).duplicate(true) as EnemyData
	enemy.setup(enemy_data, 1, false, false, 1.0)
	var context := EnemyAIContext.new(
		[hero], [enemy], {hero: 0, enemy: 0}, 77,
	)

	enemy.initialize_ai(77)
	enemy.decide_intent(context)

	assert_not_null(enemy.intended_action)
	assert_eq(enemy.intended_targets, [hero])


func test_setup_applies_scaling_without_mutating_authored_enemy_data() -> void:
	var data := EnemyData.new()
	data.enemy_name = "Elite Test"
	data.level = 3
	data.hp_rank = 4
	data.attack_rank = 6
	data.psyche_rank = 7
	data.speed_rank = 8
	data.calculate_stats()
	var authored_level := data.level
	var authored_stats := data.stats
	var expected := data.duplicate(true) as EnemyData
	expected.level = 10
	expected.calculate_stats()
	var expected_hp := expected.stats.max_hp * 5 * 2
	var expected_attack := int(expected.stats.attack * 1.15)
	var expected_psyche := int(expected.stats.psyche * 1.15)
	var expected_speed := int(expected.stats.speed * 1.15)
	var enemy := EnemyCombatant.new()
	add_child_autofree(enemy)

	enemy.setup(data, 10, true, false, 2.0)

	assert_eq(enemy.current_stats.max_hp, expected_hp)
	assert_eq(enemy.current_stats.attack, expected_attack)
	assert_eq(enemy.current_stats.psyche, expected_psyche)
	assert_eq(enemy.current_stats.speed, expected_speed)
	assert_eq(enemy.current_hp, expected_hp)
	assert_same(enemy.recover_action, enemy.enemy_data.recover_action)
	assert_eq(data.level, authored_level)
	assert_same(data.stats, authored_stats)


func test_recovery_intent_and_clear_are_owned_by_enemy_combatant() -> void:
	var enemy := _enemy_with_ability(_ability(&"basic", 0, 0))
	enemy.is_breached = true
	enemy.current_guard = 0
	var context := EnemyAIContext.new([], [enemy], {enemy: 0}, 77)

	enemy.decide_intent(context)

	assert_true(enemy.intended_decision.is_recovery)
	assert_same(enemy.intended_action, enemy.recover_action)
	assert_eq(enemy.intended_targets, [enemy])
	enemy.clear_intent()
	assert_null(enemy.intended_action)
	assert_true(enemy.intended_targets.is_empty())


func test_cooldown_completion_and_target_revalidation_are_model_owned() -> void:
	var ability := _ability(&"burst", 3, 1)
	var enemy := _enemy_with_ability(ability)
	var first := _hero("First", 0)
	var second := _hero("Second", 1)
	var context := EnemyAIContext.new(
		[first, second], [enemy], {first: 10, second: 20, enemy: 0}, 77,
	)
	enemy.initialize_ai(77)
	assert_eq(enemy.ai_state.remaining(&"burst"), 1)
	enemy.complete_ai_turn()
	assert_eq(enemy.ai_state.remaining(&"burst"), 0)
	enemy.decide_intent(context)
	var original := enemy.intended_targets[0]
	original.is_defeated = true

	var changed := enemy.revalidate_intent_targets(context)
	enemy.complete_ai_turn(&"burst")

	assert_true(changed)
	assert_eq(enemy.intended_targets, [second if original == first else first])
	assert_eq(enemy.ai_state.completed_turns, 2)
	assert_eq(enemy.ai_state.remaining(&"burst"), 3)
	first.free()
	second.free()


func _ability(id: StringName, cooldown: int, initial_cooldown: int) -> EnemyAbility:
	var selector := EnemyTargetSelector.new()
	selector.type = EnemyTargetSelector.Type.SEEDED_HERO
	var rule := EnemyDecisionRule.new()
	rule.selector = selector
	var ability := EnemyAbility.new()
	ability.ability_id = id
	ability.action = Action.new()
	ability.action.target_type = Action.TargetType.ONE_ENEMY
	ability.cooldown_turns = cooldown
	ability.initial_cooldown = initial_cooldown
	ability.rules = [rule]
	return ability


func _enemy_with_ability(ability: EnemyAbility) -> EnemyCombatant:
	var data := EnemyData.new()
	data.enemy_name = "Headless Enemy"
	data.abilities = [ability]
	var enemy := EnemyCombatant.new()
	add_child_autofree(enemy)
	enemy.setup(data, 1, false, false, 1.0)
	enemy.initialize_ai(77)
	return enemy


func _hero(actor_name: String, priority: int) -> HeroCombatant:
	var hero := HeroCombatant.new()
	var stats := ActorStats.new()
	stats.actor_name = actor_name
	stats.max_hp = 100
	hero.setup_base(stats, BattleCombatant.Faction.HERO)
	hero.battle_priority = priority
	return hero
