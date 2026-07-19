extends GutTest


func test_build_unlocks_every_role_and_owns_every_nonstructural_node() -> void:
	var result := EndgamePartyFactory.build(
		ProgressionSystem.catalog,
		EndgamePartyFactory.EquipmentPreset.SKILLS_ONLY,
	)

	assert_true(result.success, result.error)
	assert_eq(result.roster.size(), 3)
	for hero: HeroData in result.roster:
		assert_eq(hero.unlocked_role_ids.size(), hero.role_definitions.size(), hero.hero_id)
		assert_eq(hero.battle_roles.size(), hero.role_definitions.size(), hero.hero_id)
		assert_eq(hero.injuries, 0, hero.hero_id)
		assert_false(hero.boon_focused, hero.hero_id)
		assert_false(hero.boon_armored, hero.hero_id)
		for role_id: String in hero.unlocked_role_ids:
			var tree := ProgressionSystem.catalog.get_role(role_id)
			var expected := tree.nodes.filter(
				func(node: ProgressionNodeDefinition) -> bool: return not node.is_structural
			)
			var progress: HeroRoleProgress = hero.role_progress[role_id]
			assert_eq(
				progress.owned_node_ids,
				expected.map(func(node: ProgressionNodeDefinition) -> String: return node.id),
				"%s/%s" % [hero.hero_id, role_id],
			)


func test_build_overlays_complete_authored_role_kits_and_preserves_json_only_fields() -> void:
	var result := EndgamePartyFactory.build(
		ProgressionSystem.catalog,
		EndgamePartyFactory.EquipmentPreset.SKILLS_ONLY,
	)
	assert_true(result.success, result.error)

	for hero: HeroData in result.roster:
		for definition: RoleDefinition in hero.role_definitions:
			var role := hero.battle_roles.get(definition.role_id) as RoleData
			assert_not_null(role, "%s/%s" % [hero.hero_id, definition.role_id])
			if not definition.actions.is_empty():
				assert_eq(role.actions.size(), definition.actions.size(), definition.role_id)
				for action_index in definition.actions.size():
					assert_same(role.actions[action_index], definition.actions[action_index])
			if definition.passive != null:
				assert_same(role.passive, definition.passive, definition.role_id)
			if definition.shift_action != null:
				assert_same(role.shift_action, definition.shift_action, definition.role_id)

	var echo: HeroData = result.roster.filter(
		func(hero: HeroData) -> bool: return hero.hero_id == "echo"
	)[0]
	var psion := echo.battle_roles["psi"] as RoleData
	assert_eq(psion.shift_action.action_name, "Shatter")
	assert_true(psion.shift_action.is_shift_action)
	var has_mind_storm := false
	for action: Action in psion.actions:
		if action != null and action.action_name == "Mind Storm":
			has_mind_storm = true
	assert_true(has_mind_storm)

	var asher: HeroData = result.roster.filter(
		func(hero: HeroData) -> bool: return hero.hero_id == "asher"
	)[0]
	var operative := asher.battle_roles["opr"] as RoleData
	assert_eq(
		operative.actions.map(func(action: Action) -> String: return action.action_name),
		["Coordinate", "Decoy", "Debilitate", "Ensnare"],
	)
	assert_eq(operative.shift_action.action_name, "Dismantle")
	assert_eq(operative.passive.action_name, "Teamwork")

	var telepath := echo.battle_roles["dom"] as RoleData
	assert_eq(telepath.role_name, "Telepath")
	assert_eq(
		telepath.actions.map(func(action: Action) -> String: return action.action_name),
		["Displace", "Feedback", "Static Charge", "Inversion"],
	)
	assert_eq(telepath.shift_action.action_name, "Suppress")
	assert_eq(telepath.passive.action_name, "Precognition")


func test_max_equipment_uses_deep_duplicates_at_tier_five_rank_thirty() -> void:
	var authored_before := {}
	for hero_id: String in ["asher", "echo", "sands"]:
		var source := _load_authored_hero(hero_id)
		authored_before[hero_id] = {
			"weapon_rank": source.weapon.rank,
			"weapon_tier": source.weapon.tier,
			"weapon_xp": source.weapon.current_xp,
			"armor_rank": source.armor.rank,
			"armor_tier": source.armor.tier,
			"armor_xp": source.armor.current_xp,
		}

	var result := EndgamePartyFactory.build(
		ProgressionSystem.catalog,
		EndgamePartyFactory.EquipmentPreset.MAX_EQUIPMENT,
	)

	assert_true(result.success, result.error)
	for hero: HeroData in result.roster:
		assert_eq(hero.weapon.tier, 5, hero.hero_id)
		assert_eq(hero.weapon.rank, 30, hero.hero_id)
		assert_eq(hero.weapon.current_xp, 0, hero.hero_id)
		assert_eq(hero.armor.tier, 5, hero.hero_id)
		assert_eq(hero.armor.rank, 30, hero.hero_id)
		assert_eq(hero.armor.current_xp, 0, hero.hero_id)
		var authored := _load_authored_hero(hero.hero_id)
		assert_not_same(hero.weapon, authored.weapon)
		assert_not_same(hero.armor, authored.armor)
		assert_eq(authored.weapon.rank, authored_before[hero.hero_id].weapon_rank)
		assert_eq(authored.weapon.tier, authored_before[hero.hero_id].weapon_tier)
		assert_eq(authored.weapon.current_xp, authored_before[hero.hero_id].weapon_xp)
		assert_eq(authored.armor.rank, authored_before[hero.hero_id].armor_rank)
		assert_eq(authored.armor.tier, authored_before[hero.hero_id].armor_tier)
		assert_eq(authored.armor.current_xp, authored_before[hero.hero_id].armor_xp)


func test_skills_only_preserves_authored_equipment_progression_on_duplicates() -> void:
	var result := EndgamePartyFactory.build(
		ProgressionSystem.catalog,
		EndgamePartyFactory.EquipmentPreset.SKILLS_ONLY,
	)

	assert_true(result.success, result.error)
	for hero: HeroData in result.roster:
		var authored := _load_authored_hero(hero.hero_id)
		assert_not_same(hero.weapon, authored.weapon)
		assert_not_same(hero.armor, authored.armor)
		assert_eq(hero.weapon.rank, authored.weapon.rank, hero.hero_id)
		assert_eq(hero.weapon.tier, authored.weapon.tier, hero.hero_id)
		assert_eq(hero.armor.rank, authored.armor.rank, hero.hero_id)
		assert_eq(hero.armor.tier, authored.armor.tier, hero.hero_id)


func test_build_rejects_missing_catalog_without_partial_roster() -> void:
	var result := EndgamePartyFactory.build(
		null,
		EndgamePartyFactory.EquipmentPreset.SKILLS_ONLY,
	)

	assert_false(result.success)
	assert_true(result.roster.is_empty())
	assert_string_contains(result.error, "catalog")


func _load_authored_hero(hero_id: String) -> HeroData:
	return load("res://data/heroes/%s/%s.tres" % [hero_id, hero_id]) as HeroData
