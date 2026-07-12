extends GutTest

const TEST_ROOT = "user://test_saves/save_system_isolation/"
const TEST_SLOT_PATH = TEST_ROOT + "slot_1.json"
const PRODUCTION_SLOT_PATH = "user://saves/slot_1.json"

var _test_slot_existed := false
var _test_slot_bytes := PackedByteArray()
var _test_save_dir_existed := false
var _saved_data: Dictionary
var _saved_bits: int
var _saved_party_roster: Array[HeroData]
var _saved_total_lifetime_xp: int
var _saved_inventory: Dictionary
var _saved_inventory_equipment: Array[Equipment]
var _saved_inventory_mods: Array[EquipmentMod]
var _saved_run_active: bool
var _saved_last_load_issues: Array[String]
var _saved_progression_catalog: ProgressionCatalog
var _saved_current_slot_index: int
var _saved_storage_root_override: String


func before_each() -> void:
	_saved_storage_root_override = SaveSystem.storage_root_override
	SaveSystem.storage_root_override = TEST_ROOT
	_test_save_dir_existed = DirAccess.dir_exists_absolute(TEST_ROOT)
	_test_slot_existed = FileAccess.file_exists(TEST_SLOT_PATH)
	_test_slot_bytes = FileAccess.get_file_as_bytes(TEST_SLOT_PATH) if _test_slot_existed else PackedByteArray()
	_saved_data = SaveSystem.data.duplicate(true)
	_saved_bits = SaveSystem.bits
	_saved_party_roster = SaveSystem.party_roster.duplicate()
	_saved_total_lifetime_xp = SaveSystem.total_lifetime_xp
	_saved_inventory = SaveSystem.inventory.duplicate(true)
	_saved_inventory_equipment = SaveSystem.inventory_equipment.duplicate()
	_saved_inventory_mods = SaveSystem.inventory_mods.duplicate()
	_saved_run_active = RunManager.is_run_active
	_saved_last_load_issues = SaveSystem.last_load_issues.duplicate()
	_saved_progression_catalog = ProgressionSystem.catalog
	_saved_current_slot_index = SaveSystem.current_slot_index


func after_each() -> void:
	_restore_file(TEST_SLOT_PATH, _test_slot_existed, _test_slot_bytes)
	if not _test_save_dir_existed and DirAccess.dir_exists_absolute(TEST_ROOT):
		DirAccess.remove_absolute(TEST_ROOT)
	SaveSystem.data = _saved_data
	SaveSystem.bits = _saved_bits
	SaveSystem.party_roster = _saved_party_roster
	SaveSystem.total_lifetime_xp = _saved_total_lifetime_xp
	SaveSystem.inventory = _saved_inventory
	SaveSystem.inventory_equipment = _saved_inventory_equipment
	SaveSystem.inventory_mods = _saved_inventory_mods
	RunManager.is_run_active = _saved_run_active
	SaveSystem.last_load_issues = _saved_last_load_issues
	ProgressionSystem.catalog = _saved_progression_catalog
	SaveSystem.current_slot_index = _saved_current_slot_index
	SaveSystem.storage_root_override = _saved_storage_root_override


func _restore_file(path: String, existed: bool, bytes: PackedByteArray) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_buffer(bytes)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _write_test_slot(document: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	var file := FileAccess.open(TEST_SLOT_PATH, FileAccess.WRITE)
	assert_not_null(file)
	if file:
		file.store_string(JSON.stringify(document))


func _fresh_default_catalog() -> ProgressionCatalog:
	var trees: Array[RoleTreeDefinition] = []
	var seen := {}
	for hero_path in [
		"res://data/heroes/asher/asher.tres",
		"res://data/heroes/echo/echo.tres",
		"res://data/heroes/sands/sands.tres",
	]:
		var hero: HeroData = load(hero_path)
		for role_id: String in hero.unlocked_role_ids:
			if seen.has(role_id):
				continue
			seen[role_id] = true
			var first_id := "gun.root" if role_id == "gun" else "%s.first" % role_id
			var second_id := "gun.fusion_ammo" if role_id == "gun" else "%s.second" % role_id
			trees.append(RoleTreeDefinition.new(role_id, 3, [
				ProgressionNodeDefinition.role_anchor("%s.anchor" % role_id, 1, 0),
				ProgressionNodeDefinition.progression(first_id, "%s.anchor" % role_id, 1, -1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/double_tap.tres", 1), true),
				ProgressionNodeDefinition.progression(second_id, "%s.anchor" % role_id, 1, 1, 0, ProgressionEffect.action("res://data/heroes/asher/actions/fusion_ammo.tres", 2), true),
			]))
	return ProgressionCatalog.from_validated_trees(trees)


func test_storage_root_defaults_to_production_and_explicit_override_is_isolated() -> void:
	SaveSystem.storage_root_override = ""
	assert_eq(SaveSystem._get_save_dir(), SaveSystem.SAVE_DIR)
	assert_eq(SaveSystem._get_slot_path(1), PRODUCTION_SLOT_PATH)
	SaveSystem.storage_root_override = TEST_ROOT
	assert_eq(SaveSystem._get_save_dir(), TEST_ROOT)
	assert_eq(SaveSystem._get_slot_path(1), TEST_SLOT_PATH)
	assert_ne(SaveSystem._get_slot_path(1), PRODUCTION_SLOT_PATH)


func test_save_game_recreates_only_explicit_test_root() -> void:
	if FileAccess.file_exists(TEST_SLOT_PATH):
		assert_eq(DirAccess.remove_absolute(TEST_SLOT_PATH), OK)
	if DirAccess.dir_exists_absolute(TEST_ROOT):
		assert_eq(DirAccess.remove_absolute(TEST_ROOT), OK)
	SaveSystem.data = {}
	SaveSystem.bits = 314
	SaveSystem.party_roster = []
	SaveSystem.total_lifetime_xp = 271
	SaveSystem.inventory = {"test_material": 2}
	SaveSystem.inventory_equipment = []
	SaveSystem.inventory_mods = []
	RunManager.is_run_active = false

	SaveSystem.save_game(1)

	assert_true(FileAccess.file_exists(TEST_SLOT_PATH))
	assert_eq(SaveSystem._get_slot_path(1), TEST_SLOT_PATH)


func test_title_new_campaign_writes_only_under_explicit_test_root() -> void:
	ProgressionSystem.catalog = _fresh_default_catalog()
	var title := TitleScreen.new()
	watch_signals(title)
	title._on_new_game_pressed()
	assert_signal_emit_count(title, "new_game_requested", 1)
	assert_true(FileAccess.file_exists(TEST_SLOT_PATH))
	assert_true(SaveSystem._get_slot_path(1).begins_with(TEST_ROOT))
	assert_ne(SaveSystem._get_slot_path(1), PRODUCTION_SLOT_PATH)
	title.free()


func test_load_game_reports_intentional_legacy_progression_reset_without_mapping_ids() -> void:
	_write_test_slot({"heroes": [{
		"hero_id": "asher",
		"current_xp": 777,
		"unlocked_role_ids": ["gun"],
		"unlocked_node_ids": ["gun_1", "gun_311"],
	}]})

	assert_true(SaveSystem.load_game(1))
	assert_eq(SaveSystem.party_roster.size(), 1)
	assert_true(SaveSystem.party_roster[0].role_progress.is_empty())
	assert_eq(SaveSystem.party_roster[0].current_xp, 777)
	assert_eq(SaveSystem.last_load_issues, ["Hero 'asher': legacy progression data is incompatible and was intentionally reset."])
	assert_push_warning("Hero 'asher': legacy progression data is incompatible and was intentionally reset.")


func test_load_game_reports_catalog_revision_mismatch_without_reset_or_refund() -> void:
	ProgressionSystem.catalog = _fresh_default_catalog()
	var gun_revision: int = ProgressionSystem.catalog.get_role("gun").version
	_write_test_slot({"heroes": [{
		"hero_id": "asher",
		"current_xp": 555,
		"unlocked_role_ids": ["gun"],
		"role_progress": {"gun": {
			"content_revision": gun_revision + 1,
			"owned_node_ids": ["gun.root"],
			"xp_paid_by_node": {"gun.root": 100},
		}},
	}]})

	assert_true(SaveSystem.load_game(1))
	var hero: HeroData = SaveSystem.party_roster[0]
	assert_eq(hero.current_xp, 555)
	assert_eq(hero.role_progress.gun.content_revision, gun_revision + 1)
	assert_eq(hero.role_progress.gun.owned_node_ids, ["gun.root"])
	assert_eq(hero.role_progress.gun.xp_paid_by_node, {"gun.root": 100})
	var expected := "Hero 'asher' role 'gun': saved progression revision %d does not match content revision %d; progression was preserved without reset or refund." % [gun_revision + 1, gun_revision]
	assert_eq(SaveSystem.last_load_issues, [expected])
	assert_push_warning(expected)


func test_new_campaign_and_unlocked_hero_receive_fresh_starting_progress() -> void:
	ProgressionSystem.catalog = _fresh_default_catalog()
	var original_roster_reference := SaveSystem.party_roster
	assert_true(SaveSystem.start_new_campaign(1))
	assert_true(is_same(SaveSystem.party_roster, original_roster_reference))
	assert_false(SaveSystem.party_roster.is_empty())
	var asher: HeroData = SaveSystem.party_roster[0]
	assert_eq(asher.role_progress.gun.owned_node_ids, ["gun.root", "gun.fusion_ammo"])
	var before := SaveSystem.party_roster.size()
	SaveSystem.unlock_hero("asher")
	assert_eq(SaveSystem.party_roster.size(), before + 1)
	assert_eq(SaveSystem.party_roster[-1].role_progress.gun.xp_paid_by_node, {"gun.root": 0, "gun.fusion_ammo": 0})


func test_failed_fresh_initialization_does_not_commit_campaign_or_unlocked_hero() -> void:
	var loaded := ProgressionJsonLoader.load_file("res://test/fixtures/progression/valid_role.json")
	assert_true(loaded.errors.is_empty())
	# The fixture has gun but intentionally lacks Asher's other unlocked role, snp.
	ProgressionSystem.catalog = ProgressionCatalog.from_validated_trees([loaded.tree])
	var sentinel := HeroData.new()
	SaveSystem.party_roster = [sentinel]
	SaveSystem.data = {"sentinel": true}
	SaveSystem.current_slot_index = 7
	SaveSystem.bits = 42
	var slot_existed := FileAccess.file_exists(TEST_SLOT_PATH)
	var slot_bytes := FileAccess.get_file_as_bytes(TEST_SLOT_PATH) if slot_existed else PackedByteArray()

	assert_false(SaveSystem.start_new_campaign(1))

	assert_eq(SaveSystem.party_roster.size(), 1)
	assert_true(is_same(SaveSystem.party_roster[0], sentinel))
	assert_eq(SaveSystem.data, {"sentinel": true})
	assert_eq(SaveSystem.current_slot_index, 7)
	assert_eq(SaveSystem.bits, 42)
	assert_eq(FileAccess.file_exists(TEST_SLOT_PATH), slot_existed)
	if slot_existed:
		assert_eq(FileAccess.get_file_as_bytes(TEST_SLOT_PATH), slot_bytes)

	var before_unlock := SaveSystem.party_roster.duplicate()
	assert_false(SaveSystem.unlock_hero("asher"))
	assert_eq(SaveSystem.party_roster, before_unlock)


func test_title_screen_new_game_signal_follows_campaign_creation_result_exactly() -> void:
	var loaded := ProgressionJsonLoader.load_file("res://test/fixtures/progression/valid_role.json")
	assert_true(loaded.errors.is_empty())
	var title := TitleScreen.new()
	watch_signals(title)

	ProgressionSystem.catalog = ProgressionCatalog.from_validated_trees([loaded.tree])
	title._on_new_game_pressed()
	assert_signal_not_emitted(title, "new_game_requested")

	ProgressionSystem.catalog = _fresh_default_catalog()
	title._on_new_game_pressed()
	assert_signal_emit_count(title, "new_game_requested", 1)
	title.free()
