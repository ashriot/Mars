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


func test_hero_guard_cap_clamps_guard_and_enters_danger_at_zero() -> void:
	var hero := HeroCombatant.new()
	add_child_autofree(hero)
	hero.setup(_hero_data_with_three_roles())

	await hero.modify_guard(99)

	assert_eq(hero.current_guard, 10)
	assert_eq(hero.get_guard_cap(), 10)
	await hero.modify_guard(-99)
	assert_eq(hero.current_guard, 0)
	assert_true(hero.is_in_danger)


func test_setup_loads_equipment_traits_consumes_boons_and_applies_injuries() -> void:
	var data := _hero_data_with_three_roles()
	data.stats.max_hp = 100
	data.stats.starting_guard = 2
	data.stats.starting_focus = 3
	data.boon_focused = true
	data.boon_armored = true
	data.injuries = 1
	var weapon := Equipment.new()
	weapon.tier = 4
	weapon.unique_trait = Trait.new()
	weapon.unique_trait.trait_name = "Weapon Trait"
	data.weapon = weapon
	var armor := Equipment.new()
	armor.tier = 2
	armor.unique_trait = Trait.new()
	armor.unique_trait.trait_name = "Armor Trait"
	data.armor = armor
	var hero := HeroCombatant.new()
	add_child_autofree(hero)

	hero.setup(data)

	assert_eq(hero.current_focus, 8)
	assert_eq(hero.current_guard, 7)
	assert_eq(hero.current_hp, 66)
	assert_false(data.boon_focused)
	assert_false(data.boon_armored)
	assert_eq(hero.active_traits.map(func(item: Trait): return item.trait_name), [
		"Weapon Trait", "Armor Trait",
	])
	assert_eq(hero.active_traits.map(func(item: Trait): return item.current_tier), [4, 2])
	assert_not_same(hero.active_traits[0], weapon.unique_trait)


func test_focus_spend_refunds_cost_and_publishes_both_changes_without_a_card() -> void:
	var hero := HeroCombatant.new()
	add_child_autofree(hero)
	hero.setup(_hero_data_with_three_roles())
	var refund := Condition.new()
	refund.condition_name = "Refund"
	refund.refund_focus_cost_on_spend = true
	hero.active_conditions = [refund]
	var published_values: Array[int] = []
	hero.focus_changed.connect(func(changed: HeroCombatant):
		published_values.append(changed.current_focus)
	)

	await hero.modify_focus(-3, {"paid_focus_cost": 3})

	assert_eq(hero.current_focus, 5)
	assert_eq(published_values, [2, 5])


func test_defeat_and_reviving_heal_publish_model_lifecycle_once() -> void:
	var hero := HeroCombatant.new()
	add_child_autofree(hero)
	hero.setup(_hero_data_with_three_roles())
	var counts := {"defeated": 0, "revived": 0}
	hero.defeated.connect(func(_actor: BattleCombatant): counts.defeated += 1)
	hero.revived.connect(func(_actor: BattleCombatant): counts.revived += 1)

	hero.current_hp = 0
	hero.defeat()
	hero.defeat()
	await hero.take_healing(20, true)
	await hero.take_healing(20, true)

	assert_false(hero.is_defeated)
	assert_eq(hero.current_hp, 40)
	assert_eq(counts.defeated, 1)
	assert_eq(counts.revived, 1)
