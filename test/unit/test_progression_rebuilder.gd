extends GutTest

const ACTION_PATH := "res://data/heroes/asher/actions/double_tap.tres"
const PASSIVE_PATH := "res://data/heroes/asher/actions/inspire.tres"
const SHIFT_PATH := "res://data/heroes/asher/actions/bullet_time.tres"


func _definition(role_id: String) -> RoleDefinition:
	var definition := RoleDefinition.new()
	definition.role_id = role_id
	definition.role_name = role_id
	return definition


func _tree(role_id: String, nodes: Array[ProgressionNodeDefinition]) -> RoleTreeDefinition:
	return RoleTreeDefinition.new(role_id, 1, nodes)


func _node(id: String, parent: String, rank: int, column: int, effect: ProgressionEffect) -> ProgressionNodeDefinition:
	return ProgressionNodeDefinition.new(id, parent, rank, column, 1, effect)


func test_rebuild_applies_every_effect_without_mutating_definitions() -> void:
	var definition := _definition("gun")
	var nodes: Array[ProgressionNodeDefinition] = [
		_node("gun.root", "", 1, 0, ProgressionEffect.stat("ATK", 3)),
		_node("gun.action", "gun.root", 2, 0, ProgressionEffect.action(ACTION_PATH, 1)),
		_node("gun.passive", "gun.root", 2, 1, ProgressionEffect.passive(PASSIVE_PATH)),
		_node("gun.shift", "gun.action", 3, 0, ProgressionEffect.shift_action(SHIFT_PATH)),
	]
	var catalog := ProgressionCatalog.from_validated_trees([_tree("gun", nodes)])
	var hero := HeroData.new()
	hero.role_definitions = [definition]
	hero.unlocked_role_ids = ["gun"]
	hero.role_progress["gun"] = HeroRoleProgress.new(1, ["gun.shift", "gun.passive", "gun.action", "gun.root"])

	var result := ProgressionRebuilder.new(catalog).rebuild(hero)

	assert_true(result.success)
	assert_eq(hero.stats.attack, 3)
	assert_eq(hero.stats.aim, 10)
	assert_eq(hero.battle_roles.gun.actions.size(), 4)
	assert_eq(hero.battle_roles.gun.actions[0].resource_path, ACTION_PATH)
	assert_eq(hero.battle_roles.gun.passive.resource_path, PASSIVE_PATH)
	assert_eq(hero.battle_roles.gun.shift_action.resource_path, SHIFT_PATH)
	assert_true(definition.actions.is_empty())
	assert_null(definition.passive)
	assert_null(definition.shift_action)


func test_rebuild_preserves_equipment_and_legacy_base_calculation() -> void:
	var weapon := Equipment.new()
	weapon.slot = Equipment.Slot.WEAPON
	weapon.star_atk = 2
	var hero := HeroData.new()
	hero.weapon = weapon
	hero.unlocked_role_ids = ["gun"]
	hero.role_definitions = [_definition("gun")]
	var catalog := ProgressionCatalog.from_validated_trees([_tree("gun", [_node("gun.root", "", 1, 0, ProgressionEffect.stat("HP", 7))])])
	hero.role_progress["gun"] = HeroRoleProgress.new(1, ["gun.root"])
	var expected_equipment_attack := weapon.calculate_stats().attack

	assert_true(ProgressionRebuilder.new(catalog).rebuild(hero).success)
	assert_eq(hero.stats.attack, expected_equipment_attack)
	assert_eq(hero.stats.max_hp, 7)
	assert_eq(hero.stats.aim, weapon.calculate_stats().aim + 10)


func test_rebuild_uses_deterministic_tree_order_and_is_idempotent() -> void:
	var nodes: Array[ProgressionNodeDefinition] = [
		_node("gun.root", "", 1, 0, ProgressionEffect.stat("ATK", 1)),
		_node("gun.zeta", "gun.root", 2, 1, ProgressionEffect.action(SHIFT_PATH, 1)),
		_node("gun.alpha", "gun.root", 2, -1, ProgressionEffect.action(ACTION_PATH, 1)),
	]
	var hero := HeroData.new()
	hero.role_definitions = [_definition("gun")]
	hero.unlocked_role_ids = ["gun"]
	hero.role_progress["gun"] = HeroRoleProgress.new(1, ["gun.zeta", "gun.root", "gun.alpha"])
	var rebuilder := ProgressionRebuilder.new(ProgressionCatalog.from_validated_trees([_tree("gun", nodes)]))

	assert_true(rebuilder.rebuild(hero).success)
	assert_eq(hero.battle_roles.gun.actions[0].resource_path, SHIFT_PATH)
	var first_stats := hero.stats
	var first_role: RoleData = hero.battle_roles.gun
	assert_true(rebuilder.rebuild(hero).success)
	assert_eq(hero.stats.attack, 1)
	assert_eq(hero.battle_roles.gun.actions[0].resource_path, SHIFT_PATH)
	assert_false(is_same(first_stats, hero.stats))
	assert_false(is_same(first_role, hero.battle_roles.gun))


func test_rebuild_rejects_unknown_owned_node_without_partial_publish() -> void:
	var hero := HeroData.new()
	hero.role_definitions = [_definition("gun")]
	hero.unlocked_role_ids = ["gun"]
	hero.role_progress["gun"] = HeroRoleProgress.new(1, ["missing", "gun.root"])
	var old_stats := ActorStats.new()
	old_stats.attack = 77
	hero.stats = old_stats
	var old_roles := {"old": RoleData.new()}
	hero.battle_roles = old_roles
	var catalog := ProgressionCatalog.from_validated_trees([_tree("gun", [_node("gun.root", "", 1, 0, ProgressionEffect.stat("ATK", 2))])])

	var result := ProgressionRebuilder.new(catalog).rebuild(hero)
	assert_false(result.success)
	assert_string_contains(result.error, "gun")
	assert_string_contains(result.error, "missing")
	assert_true(is_same(hero.stats, old_stats))
	assert_true(is_same(hero.battle_roles, old_roles))


func test_rebuild_rejects_unknown_role_record_without_partial_publish() -> void:
	var hero := HeroData.new()
	hero.role_definitions = [_definition("gun")]
	hero.role_progress["orphan"] = HeroRoleProgress.new(1, ["orphan.root"])
	var old_stats := ActorStats.new()
	hero.stats = old_stats
	var old_roles := {"old": RoleData.new()}
	hero.battle_roles = old_roles
	var catalog := ProgressionCatalog.from_validated_trees([_tree("gun", [_node("gun.root", "", 1, 0, ProgressionEffect.stat("ATK", 2))])])

	var result := ProgressionRebuilder.new(catalog).rebuild(hero)
	assert_false(result.success)
	assert_string_contains(result.error, "orphan")
	assert_true(is_same(hero.stats, old_stats))
	assert_true(is_same(hero.battle_roles, old_roles))


func test_rebuild_validates_but_does_not_apply_locked_role_progress() -> void:
	var hero := HeroData.new()
	hero.role_definitions = [_definition("gun"), _definition("blade")]
	hero.unlocked_role_ids = ["gun"]
	hero.role_progress["blade"] = HeroRoleProgress.new(1, ["blade.root"])
	var catalog := ProgressionCatalog.from_validated_trees([
		_tree("blade", [_node("blade.root", "", 1, 0, ProgressionEffect.stat("ATK", 100))]),
		_tree("gun", [_node("gun.root", "", 1, 0, ProgressionEffect.stat("ATK", 2))]),
	])

	assert_true(ProgressionRebuilder.new(catalog).rebuild(hero).success)
	assert_eq(hero.stats.attack, 0)
	assert_true(hero.battle_roles.has("gun"))
	assert_false(hero.battle_roles.has("blade"))


func test_failed_rebuild_is_transactional_for_invalid_resource() -> void:
	var hero := HeroData.new()
	hero.role_definitions = [_definition("gun")]
	hero.unlocked_role_ids = ["gun"]
	hero.stats = ActorStats.new()
	hero.stats.attack = 44
	var old_stats := hero.stats
	var old_roles := {"sentinel": RoleData.new()}
	hero.battle_roles = old_roles
	var catalog := ProgressionCatalog.from_validated_trees([_tree("gun", [_node("gun.root", "", 1, 0, ProgressionEffect.action("res://missing/action.tres", 1))])])
	hero.role_progress["gun"] = HeroRoleProgress.new(1, ["gun.root"])

	var result := ProgressionRebuilder.new(catalog).rebuild(hero)

	assert_false(result.success)
	assert_true(is_same(hero.stats, old_stats))
	assert_eq(hero.stats.attack, 44)
	assert_eq(hero.battle_roles, old_roles)


func test_action_slots_are_one_based_and_bounded_to_four() -> void:
	var applier := ProgressionEffectApplier.new()
	var role := RoleData.new()
	var stats := ActorStats.new()
	assert_true(applier.apply(ProgressionEffect.action(ACTION_PATH, 1), stats, role))
	assert_true(applier.apply(ProgressionEffect.action(SHIFT_PATH, 4), stats, role))
	assert_eq(role.actions[0].resource_path, ACTION_PATH)
	assert_eq(role.actions[3].resource_path, SHIFT_PATH)
	assert_false(applier.apply(ProgressionEffect.new(ProgressionEffect.Type.ACTION, ACTION_PATH, 0), stats, role))
	assert_false(applier.apply(ProgressionEffect.action(ACTION_PATH, 5), stats, role))


func test_precision_stat_effect_updates_precision() -> void:
	var hero := HeroData.new()
	hero.role_definitions = [_definition("gun")]
	hero.unlocked_role_ids = ["gun"]
	hero.role_progress["gun"] = HeroRoleProgress.new(1, ["gun.root"])
	var catalog := ProgressionCatalog.from_validated_trees([_tree("gun", [_node("gun.root", "", 1, 0, ProgressionEffect.stat("PRE", 6))])])

	var result := ProgressionRebuilder.new(catalog).rebuild(hero)

	assert_true(result.success)
	assert_eq(hero.stats.precision, 6)
	assert_eq(hero.stats.get_stat(ActorStats.Stats.PRE), 6)
