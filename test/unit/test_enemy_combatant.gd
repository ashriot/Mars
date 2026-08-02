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
