extends GutTest

const FIXTURES := "res://test/fixtures/progression"

var catalog: ProgressionCatalog
var rebuild_count := 0
var rebuild_observation: Dictionary = {}


func before_each() -> void:
	catalog = ProgressionCatalog.new()
	var loaded := ProgressionJsonLoader.load_file(FIXTURES.path_join("valid_role.json"))
	assert_true(loaded.errors.is_empty())
	catalog = ProgressionCatalog.from_validated_trees([loaded.tree])
	rebuild_count = 0
	rebuild_observation.clear()


func _service(effect_validator := Callable()) -> ProgressionService:
	return ProgressionService.new(catalog, func(hero):
		rebuild_count += 1
		var progress: HeroRoleProgress = hero.role_progress.get("gun")
		rebuild_observation = {
			"xp": hero.current_xp,
			"owned": progress.owned_node_ids.duplicate() if progress else [],
			"paid": progress.xp_paid_by_node.duplicate() if progress else {},
			"revision": progress.content_revision if progress else 0,
		}, effect_validator)


func _hero(xp := 1000) -> HeroData:
	var hero := HeroData.new()
	hero.current_xp = xp
	hero.unlocked_role_ids = ["gun"]
	return hero


func _snapshot(hero: HeroData) -> Dictionary:
	return {"xp": hero.current_xp, "save": hero.get_save_data().duplicate(true), "rebuilds": rebuild_count}


func _assert_rejected_without_mutation(result: ProgressionPurchaseResult, status: ProgressionPurchaseResult.Status, hero: HeroData, before: Dictionary) -> void:
	assert_eq(result.status, status)
	assert_eq(hero.current_xp, before.xp)
	assert_eq(hero.get_save_data(), before.save)
	assert_eq(rebuild_count, before.rebuilds)
	assert_null(result.hero)
	assert_eq(result.resulting_xp, -1)
	assert_eq(result.xp_paid, 0)
	assert_eq(result.content_revision, 0)


func test_every_rejection_leaves_xp_and_progress_unchanged() -> void:
	var hero := _hero()
	var cases := [
		[null, "gun", "gun.root", ProgressionPurchaseResult.Status.INVALID_HERO],
		[hero, "blade", "blade.root", ProgressionPurchaseResult.Status.ROLE_LOCKED],
		[hero, "gun", "gun.absent", ProgressionPurchaseResult.Status.NODE_NOT_FOUND],
	]
	for entry in cases:
		var before := _snapshot(hero)
		var result := _service().purchase_node(entry[0], entry[1], entry[2])
		_assert_rejected_without_mutation(result, entry[3], hero, before)

	var poor := _hero(199)
	var poor_before := _snapshot(poor)
	_assert_rejected_without_mutation(_service().purchase_node(poor, "gun", "gun.coordinate"), ProgressionPurchaseResult.Status.INSUFFICIENT_XP, poor, poor_before)

	var mismatched := _hero()
	mismatched.role_progress["gun"] = HeroRoleProgress.new(2)
	var mismatch_before := _snapshot(mismatched)
	_assert_rejected_without_mutation(_service().purchase_node(mismatched, "gun", "gun.coordinate"), ProgressionPurchaseResult.Status.REVISION_MISMATCH, mismatched, mismatch_before)

	var invalid := _hero()
	var invalid_before := _snapshot(invalid)
	_assert_rejected_without_mutation(_service(func(_effect): return false).purchase_node(invalid, "gun", "gun.coordinate"), ProgressionPurchaseResult.Status.INVALID_EFFECT, invalid, invalid_before)


func test_purchase_commits_price_revision_and_ownership_exactly_once() -> void:
	var hero := _hero()
	var result := _service().purchase_node(hero, "gun", "gun.coordinate")
	assert_eq(result.status, ProgressionPurchaseResult.Status.PURCHASED)
	assert_eq(result.role_id, "gun")
	assert_eq(result.node_id, "gun.coordinate")
	assert_eq(result.xp_paid, 200)
	assert_eq(result.content_revision, 3)
	assert_true(is_same(result.hero, hero))
	assert_eq(result.resulting_xp, 800)
	assert_eq(hero.current_xp, 800)
	assert_eq(hero.role_progress.gun.owned_node_ids, ["gun.coordinate"])
	assert_eq(hero.role_progress.gun.xp_paid_by_node, {"gun.coordinate": 200})
	assert_eq(hero.role_progress.gun.content_revision, 3)
	assert_eq(rebuild_count, 1)
	assert_eq(rebuild_observation, {"xp": 800, "owned": ["gun.coordinate"], "paid": {"gun.coordinate": 200}, "revision": 3})

	var before_second := _snapshot(hero)
	_assert_rejected_without_mutation(_service().purchase_node(hero, "gun", "gun.coordinate"), ProgressionPurchaseResult.Status.ALREADY_OWNED, hero, before_second)


func test_purchase_rejects_structural_and_starting_nodes_before_xp_or_prerequisites() -> void:
	var hero := _hero(0)
	var structural_before := _snapshot(hero)
	_assert_rejected_without_mutation(_service().purchase_node(hero, "gun", "gun.anchor"), ProgressionPurchaseResult.Status.NODE_NOT_FOUND, hero, structural_before)
	var starting_before := _snapshot(hero)
	_assert_rejected_without_mutation(_service().purchase_node(hero, "gun", "gun.root"), ProgressionPurchaseResult.Status.ALREADY_OWNED, hero, starting_before)


func test_purchase_rejects_unowned_non_structural_paid_parent() -> void:
	var nodes: Array[ProgressionNodeDefinition] = [
		ProgressionNodeDefinition.role_anchor("gun.anchor", 1, 0),
		ProgressionNodeDefinition.progression("gun.first", "gun.anchor", 1, -1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/double_tap.tres", 1), true),
		ProgressionNodeDefinition.progression("gun.second", "gun.anchor", 1, 1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/fusion_ammo.tres", 2), true),
		ProgressionNodeDefinition.progression("gun.parent", "gun.anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
		ProgressionNodeDefinition.progression("gun.child", "gun.parent", 3, 0, 100, ProgressionEffect.stat("ATK", 1)),
	]
	var tree := RoleTreeDefinition.new("gun", 1, nodes)
	assert_true(tree.is_valid, tree.validation_error)
	var hero := _hero()
	var before := _snapshot(hero)
	var result := ProgressionService.new(ProgressionCatalog.from_validated_trees([tree])).purchase_node(hero, "gun", "gun.child")
	_assert_rejected_without_mutation(result, ProgressionPurchaseResult.Status.PREREQUISITE_LOCKED, hero, before)


func test_failed_rebuild_rolls_back_xp_and_role_record_exactly() -> void:
	var hero := _hero()
	hero.role_progress["gun"] = HeroRoleProgress.new(3, ["legacy"], {"legacy": 17})
	var original_record := hero.role_progress.gun
	var original := hero.role_progress.gun.to_save_data()
	var service := ProgressionService.new(catalog, func(_hero): return false)

	var result := service.purchase_node(hero, "gun", "gun.coordinate")

	assert_eq(result.status, ProgressionPurchaseResult.Status.INVALID_EFFECT)
	assert_eq(hero.current_xp, 1000)
	assert_true(is_same(hero.role_progress.gun, original_record))
	assert_eq(hero.role_progress.gun.to_save_data(), original)
	assert_null(result.hero)
	assert_eq(result.xp_paid, 0)


func test_failed_rebuild_restores_derived_state_after_mutating_callback() -> void:
	var hero := _hero()
	hero.stats = ActorStats.new()
	hero.stats.attack = 23
	var original_stats := hero.stats
	var original_role := RoleData.new()
	hero.battle_roles = {"gun": original_role}
	var original_roles := hero.battle_roles
	var service := ProgressionService.new(catalog, func(rebuilding_hero):
		rebuilding_hero.stats.attack = 999
		rebuilding_hero.stats = ActorStats.new()
		rebuilding_hero.battle_roles.clear()
		rebuilding_hero.battle_roles["corrupt"] = RoleData.new()
		return false
	)

	assert_eq(service.purchase_node(hero, "gun", "gun.coordinate").status, ProgressionPurchaseResult.Status.INVALID_EFFECT)
	assert_true(is_same(hero.stats, original_stats))
	assert_eq(hero.stats.attack, 23)
	assert_true(is_same(hero.battle_roles, original_roles))
	assert_eq(hero.battle_roles.keys(), ["gun"])
	assert_true(is_same(hero.battle_roles.gun, original_role))


func test_failed_rebuild_restores_mutated_fields_inside_existing_role() -> void:
	var hero := _hero()
	var definition := RoleDefinition.new()
	definition.role_id = "gun"
	var original_action: Action = load("res://data/heroes/asher/actions/double_tap.tres")
	var original_passive: Action = load("res://data/heroes/asher/actions/coordinate.tres")
	var original_shift: Action = load("res://data/heroes/asher/actions/bullet_time.tres")
	var original_role := RoleData.new()
	original_role.source_definition = definition
	original_role.actions = [original_action]
	original_role.passive = original_passive
	original_role.shift_action = original_shift
	hero.battle_roles = {"gun": original_role}
	var original_roles := hero.battle_roles
	var service := ProgressionService.new(catalog, func(rebuilding_hero):
		var role: RoleData = rebuilding_hero.battle_roles.gun
		role.source_definition = RoleDefinition.new()
		role.actions.clear()
		role.passive = null
		role.shift_action = null
		return false
	)

	assert_eq(service.purchase_node(hero, "gun", "gun.coordinate").status, ProgressionPurchaseResult.Status.INVALID_EFFECT)
	assert_true(is_same(hero.battle_roles, original_roles))
	assert_true(is_same(hero.battle_roles.gun, original_role))
	assert_true(is_same(original_role.source_definition, definition))
	assert_eq(original_role.actions.size(), 1)
	assert_true(is_same(original_role.actions[0], original_action))
	assert_true(is_same(original_role.passive, original_passive))
	assert_true(is_same(original_role.shift_action, original_shift))


func test_real_rebuilder_rolls_back_purchase_when_saved_ownership_is_invalid() -> void:
	var hero := _hero()
	var definition := RoleDefinition.new()
	definition.role_id = "gun"
	hero.role_definitions = [definition]
	hero.role_progress["gun"] = HeroRoleProgress.new(3, ["stale.node"], {"stale.node": 25})
	var original_progress := hero.role_progress.gun
	var original_stats := ActorStats.new()
	original_stats.attack = 41
	hero.stats = original_stats
	var original_roles := {"old": RoleData.new()}
	hero.battle_roles = original_roles

	var result := ProgressionService.new(catalog).purchase_node(hero, "gun", "gun.coordinate")

	assert_eq(result.status, ProgressionPurchaseResult.Status.INVALID_EFFECT)
	assert_eq(hero.current_xp, 1000)
	assert_true(is_same(hero.role_progress.gun, original_progress))
	assert_true(is_same(hero.stats, original_stats))
	assert_true(is_same(hero.battle_roles, original_roles))


func test_role_progress_save_round_trip_rejects_malformed_and_reports_revision_without_reset() -> void:
	var hero := _hero()
	hero.role_progress["gun"] = HeroRoleProgress.new(2, ["gun.root"], {"gun.root": 75})
	var saved := hero.get_save_data()
	assert_false(saved.has("unlocked_node_ids"))
	var loaded := HeroData.new()
	var issues := loaded.load_from_save_data(saved, {"gun": 3})
	assert_eq(issues, ["revision_mismatch:gun:2:3"])
	assert_eq(loaded.role_progress.gun.content_revision, 2)
	assert_eq(loaded.role_progress.gun.owned_node_ids, ["gun.root"])
	assert_eq(loaded.role_progress.gun.xp_paid_by_node, {"gun.root": 75})

	var legacy := HeroData.new()
	assert_eq(legacy.load_from_save_data({"unlocked_node_ids": ["legacy.node"]}), ["legacy_progression_reset"])
	assert_true(legacy.role_progress.is_empty())
	assert_false(legacy.get_save_data().has("unlocked_node_ids"))

	var malformed := HeroData.new()
	var malformed_issues := malformed.load_from_save_data({"role_progress": {"gun": {"content_revision": "3", "owned_node_ids": [], "xp_paid_by_node": {}}}})
	assert_eq(malformed_issues, ["invalid_role_progress:gun"])
	assert_true(malformed.role_progress.is_empty())


func test_role_progress_parser_rejects_every_malformed_boundary() -> void:
	var valid := {"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": 100}}
	var malformed := [
		null,
		[],
		{"content_revision": 3, "owned_node_ids": {}, "xp_paid_by_node": {}},
		{"content_revision": 3, "owned_node_ids": [], "xp_paid_by_node": []},
		{"content_revision": 3, "owned_node_ids": [""], "xp_paid_by_node": {"": 100}},
		{"content_revision": 3, "owned_node_ids": ["gun.root", "gun.root"], "xp_paid_by_node": {"gun.root": 100}},
		{"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.other": 100}},
		{"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {}},
		{"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": "100"}},
		{"content_revision": 3.5, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": 100}},
		{"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": 100.5}},
		{"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": -1}},
		{"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": INF}},
		{"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": NAN}},
		{"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": 1.0e30}},
	]
	assert_not_null(HeroRoleProgress.from_save_data(valid))
	assert_not_null(HeroRoleProgress.from_save_data({"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": 0}}))
	for shape in malformed:
		assert_null(HeroRoleProgress.from_save_data(shape), str(shape))
