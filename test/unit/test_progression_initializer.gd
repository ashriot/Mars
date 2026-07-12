extends GutTest

const FIXTURE := "res://test/fixtures/progression/valid_role.json"


func _catalog() -> ProgressionCatalog:
	var loaded := ProgressionJsonLoader.load_file(FIXTURE)
	assert_true(loaded.errors.is_empty())
	return ProgressionCatalog.from_validated_trees([loaded.tree])


func _hero() -> HeroData:
	var hero := HeroData.new()
	hero.current_xp = 321
	hero.unlocked_role_ids = ["gun"]
	var definition := RoleDefinition.new()
	definition.role_id = "gun"
	hero.role_definitions = [definition]
	return hero


func test_initialize_role_grants_zero_paid_starting_nodes_without_spending_xp() -> void:
	var hero := _hero()
	assert_true(ProgressionInitializer.initialize_role(hero, "gun", _catalog()))
	assert_eq(hero.role_progress.gun.owned_node_ids, ["gun.root", "gun.fusion_ammo"])
	assert_eq(hero.role_progress.gun.xp_paid_by_node, {"gun.root": 0, "gun.fusion_ammo": 0})
	assert_eq(hero.role_progress.gun.content_revision, 3)
	assert_eq(hero.current_xp, 321)


func test_initialize_role_is_idempotent_and_never_overwrites_existing_progress() -> void:
	var hero := _hero()
	var existing := HeroRoleProgress.new(3, ["legacy"], {"legacy": 17})
	hero.role_progress["gun"] = existing
	assert_true(ProgressionInitializer.initialize_role(hero, "gun", _catalog()))
	assert_true(is_same(hero.role_progress.gun, existing))


func test_initialize_role_rejects_locked_unknown_and_invalid_inputs_without_mutation() -> void:
	var hero := _hero()
	var catalog := _catalog()
	hero.unlocked_role_ids.clear()
	assert_false(ProgressionInitializer.initialize_role(hero, "gun", catalog))
	hero.unlocked_role_ids = ["gun", "missing"]
	assert_false(ProgressionInitializer.initialize_role(hero, "missing", catalog))
	assert_false(ProgressionInitializer.initialize_role(null, "gun", catalog))
	assert_true(hero.role_progress.is_empty())


func test_initialize_hero_initializes_all_unlocked_known_roles_once_and_rebuilds_actions() -> void:
	var hero := _hero()
	var result := ProgressionInitializer.initialize_hero(hero, _catalog())
	assert_true(result.success, result.error)
	assert_eq(hero.role_progress.keys(), ["gun"])
	assert_eq(hero.battle_roles.gun.actions[0].resource_path, "res://data/heroes/asher/actions/double_tap.tres")
	assert_eq(hero.battle_roles.gun.actions[1].resource_path, "res://data/heroes/asher/actions/fusion_ammo.tres")


func test_initialize_hero_rolls_back_new_records_when_rebuild_fails() -> void:
	var hero := _hero()
	hero.role_progress["orphan"] = HeroRoleProgress.new(1, ["orphan.node"], {"orphan.node": 9})
	var original_reference := hero.role_progress
	var original := hero.role_progress.duplicate()
	var result := ProgressionInitializer.initialize_hero(hero, _catalog())
	assert_false(result.success)
	assert_true(is_same(hero.role_progress, original_reference))
	assert_true(is_same(original_reference, hero.role_progress))
	assert_eq(hero.role_progress, original)
	assert_eq(original_reference, original)
	assert_false(hero.role_progress.has("gun"))
