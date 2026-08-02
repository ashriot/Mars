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


func test_focus_and_role_shift_work_without_hero_card() -> void:
	var hero := HeroCombatant.new()
	add_child_autofree(hero)
	var data := _hero_data_with_three_roles()
	hero.setup(data)
	var original := hero.get_current_role()

	await hero.modify_focus(-2, {"paid_focus_cost": 2})
	await hero.shift_role("right")

	assert_eq(hero.current_focus, data.stats.starting_focus - 2)
	assert_ne(hero.get_current_role(), original)
	assert_true(hero.shifted_this_turn)
