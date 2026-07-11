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

	var prerequisite_before := _snapshot(hero)
	_assert_rejected_without_mutation(_service().purchase_node(hero, "gun", "gun.action"), ProgressionPurchaseResult.Status.PREREQUISITE_LOCKED, hero, prerequisite_before)

	var poor := _hero(99)
	var poor_before := _snapshot(poor)
	_assert_rejected_without_mutation(_service().purchase_node(poor, "gun", "gun.root"), ProgressionPurchaseResult.Status.INSUFFICIENT_XP, poor, poor_before)

	var mismatched := _hero()
	mismatched.role_progress["gun"] = HeroRoleProgress.new(2)
	var mismatch_before := _snapshot(mismatched)
	_assert_rejected_without_mutation(_service().purchase_node(mismatched, "gun", "gun.root"), ProgressionPurchaseResult.Status.REVISION_MISMATCH, mismatched, mismatch_before)

	var invalid := _hero()
	var invalid_before := _snapshot(invalid)
	_assert_rejected_without_mutation(_service(func(_effect): return false).purchase_node(invalid, "gun", "gun.root"), ProgressionPurchaseResult.Status.INVALID_EFFECT, invalid, invalid_before)


func test_purchase_commits_price_revision_and_ownership_exactly_once() -> void:
	var hero := _hero()
	var result := _service().purchase_node(hero, "gun", "gun.root")
	assert_eq(result.status, ProgressionPurchaseResult.Status.PURCHASED)
	assert_eq(result.role_id, "gun")
	assert_eq(result.node_id, "gun.root")
	assert_eq(result.xp_paid, 100)
	assert_eq(result.content_revision, 3)
	assert_true(is_same(result.hero, hero))
	assert_eq(result.resulting_xp, 900)
	assert_eq(hero.current_xp, 900)
	assert_eq(hero.role_progress.gun.owned_node_ids, ["gun.root"])
	assert_eq(hero.role_progress.gun.xp_paid_by_node, {"gun.root": 100})
	assert_eq(hero.role_progress.gun.content_revision, 3)
	assert_eq(rebuild_count, 1)
	assert_eq(rebuild_observation, {"xp": 900, "owned": ["gun.root"], "paid": {"gun.root": 100}, "revision": 3})

	var before_second := _snapshot(hero)
	_assert_rejected_without_mutation(_service().purchase_node(hero, "gun", "gun.root"), ProgressionPurchaseResult.Status.ALREADY_OWNED, hero, before_second)


func test_failed_rebuild_rolls_back_xp_and_role_record_exactly() -> void:
	var hero := _hero()
	hero.role_progress["gun"] = HeroRoleProgress.new(3, ["legacy"], {"legacy": 17})
	var original_record := hero.role_progress.gun
	var original := hero.role_progress.gun.to_save_data()
	var service := ProgressionService.new(catalog, func(_hero): return false)

	var result := service.purchase_node(hero, "gun", "gun.root")

	assert_eq(result.status, ProgressionPurchaseResult.Status.INVALID_EFFECT)
	assert_eq(hero.current_xp, 1000)
	assert_true(is_same(hero.role_progress.gun, original_record))
	assert_eq(hero.role_progress.gun.to_save_data(), original)
	assert_null(result.hero)
	assert_eq(result.xp_paid, 0)


func test_role_progress_save_round_trip_rejects_malformed_and_reports_revision_without_reset() -> void:
	var hero := _hero()
	hero.unlocked_node_ids = ["legacy.node"]
	hero.role_progress["gun"] = HeroRoleProgress.new(2, ["gun.root"], {"gun.root": 75})
	var saved := hero.get_save_data()
	var loaded := HeroData.new()
	var issues := loaded.load_from_save_data(saved, {"gun": 3})
	assert_eq(issues, ["gun"])
	assert_eq(loaded.role_progress.gun.content_revision, 2)
	assert_eq(loaded.role_progress.gun.owned_node_ids, ["gun.root"])
	assert_eq(loaded.role_progress.gun.xp_paid_by_node, {"gun.root": 75})

	var legacy := HeroData.new()
	legacy.load_from_save_data({"unlocked_node_ids": ["legacy.node"]})
	assert_true(legacy.role_progress.is_empty())

	var malformed := HeroData.new()
	var malformed_issues := malformed.load_from_save_data({"role_progress": {"gun": {"content_revision": "3", "owned_node_ids": [], "xp_paid_by_node": {}}}})
	assert_eq(malformed_issues, ["gun"])
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
		{"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": 0}},
		{"content_revision": 3, "owned_node_ids": ["gun.root"], "xp_paid_by_node": {"gun.root": -1}},
	]
	assert_not_null(HeroRoleProgress.from_save_data(valid))
	for shape in malformed:
		assert_null(HeroRoleProgress.from_save_data(shape), str(shape))
