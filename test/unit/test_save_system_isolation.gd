extends GutTest

const TEST_SLOT_PATH = "user://test_saves/slot_1.json"
const PRODUCTION_SLOT_PATH = "user://saves/slot_1.json"

var _test_slot_existed := false
var _test_slot_bytes := PackedByteArray()
var _test_save_dir_existed := false
var _production_slot_existed := false
var _production_slot_bytes := PackedByteArray()
var _saved_data: Dictionary
var _saved_bits: int
var _saved_party_roster: Array[HeroData]
var _saved_total_lifetime_xp: int
var _saved_inventory: Dictionary
var _saved_inventory_equipment: Array[Equipment]
var _saved_inventory_mods: Array[EquipmentMod]
var _saved_run_active: bool


func before_each() -> void:
	_test_save_dir_existed = DirAccess.dir_exists_absolute(SaveSystem.TEST_SAVE_DIR)
	_test_slot_existed = FileAccess.file_exists(TEST_SLOT_PATH)
	_test_slot_bytes = FileAccess.get_file_as_bytes(TEST_SLOT_PATH) if _test_slot_existed else PackedByteArray()
	_production_slot_existed = FileAccess.file_exists(PRODUCTION_SLOT_PATH)
	_production_slot_bytes = FileAccess.get_file_as_bytes(PRODUCTION_SLOT_PATH) if _production_slot_existed else PackedByteArray()
	_saved_data = SaveSystem.data.duplicate(true)
	_saved_bits = SaveSystem.bits
	_saved_party_roster = SaveSystem.party_roster.duplicate()
	_saved_total_lifetime_xp = SaveSystem.total_lifetime_xp
	_saved_inventory = SaveSystem.inventory.duplicate(true)
	_saved_inventory_equipment = SaveSystem.inventory_equipment.duplicate()
	_saved_inventory_mods = SaveSystem.inventory_mods.duplicate()
	_saved_run_active = RunManager.is_run_active


func after_each() -> void:
	_restore_file(TEST_SLOT_PATH, _test_slot_existed, _test_slot_bytes)
	if not _test_save_dir_existed and DirAccess.dir_exists_absolute(SaveSystem.TEST_SAVE_DIR):
		DirAccess.remove_absolute(SaveSystem.TEST_SAVE_DIR)
	SaveSystem.data = _saved_data
	SaveSystem.bits = _saved_bits
	SaveSystem.party_roster = _saved_party_roster
	SaveSystem.total_lifetime_xp = _saved_total_lifetime_xp
	SaveSystem.inventory = _saved_inventory
	SaveSystem.inventory_equipment = _saved_inventory_equipment
	SaveSystem.inventory_mods = _saved_inventory_mods
	RunManager.is_run_active = _saved_run_active


func _restore_file(path: String, existed: bool, bytes: PackedByteArray) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_buffer(bytes)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_gut_runner_argument_is_detected() -> void:
	assert_true(SaveSystem._is_gut_process(PackedStringArray([
		"-s",
		"res://addons/gut/gut_cmdln.gd",
		"-gexit",
	])))


func test_unrelated_script_argument_is_not_detected_as_gut() -> void:
	assert_false(SaveSystem._is_gut_process(PackedStringArray([
		"-s",
		"res://tools/export_data.gd",
	])))


func test_current_gut_process_resolves_slot_under_test_save_root() -> void:
	assert_true(SaveSystem._is_gut_process(OS.get_cmdline_args()))
	assert_eq(SaveSystem._get_save_dir(), "user://test_saves/")
	assert_eq(SaveSystem._get_slot_path(1), TEST_SLOT_PATH)
	assert_ne(SaveSystem._get_slot_path(1), PRODUCTION_SLOT_PATH)


func test_save_game_recreates_only_test_root_and_preserves_production_slot() -> void:
	if FileAccess.file_exists(TEST_SLOT_PATH):
		assert_eq(DirAccess.remove_absolute(TEST_SLOT_PATH), OK)
	assert_eq(DirAccess.remove_absolute(SaveSystem.TEST_SAVE_DIR), OK)
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
	assert_eq(FileAccess.file_exists(PRODUCTION_SLOT_PATH), _production_slot_existed)
	if _production_slot_existed:
		assert_eq(FileAccess.get_file_as_bytes(PRODUCTION_SLOT_PATH), _production_slot_bytes)
