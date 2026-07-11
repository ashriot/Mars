extends GutTest

const PROFILE_PATH := "res://data/enemies/dungeon_profiles/first_alleyway.tres"

class RestoreMapDouble extends DungeonMap:
	var restore_result := false
	var received_data: Variant

	func load_from_save_data(data: Variant) -> bool:
		received_data = data
		return restore_result


var _saved_data: Dictionary
var _saved_map: DungeonMap
var _saved_seed: int
var _saved_bits: int
var _saved_xp: int
var _saved_inventory: Dictionary
var _saved_tier: int
var _saved_profile: DungeonProfile
var _saved_active: bool
var _saved_committed: bool


func before_each() -> void:
	_saved_data = SaveSystem.data
	_saved_map = RunManager.active_dungeon_map
	_saved_seed = RunManager.current_run_seed
	_saved_bits = RunManager.run_bits
	_saved_xp = RunManager.run_xp
	_saved_inventory = RunManager.run_inventory
	_saved_tier = RunManager.current_dungeon_tier
	_saved_profile = RunManager.dungeon_profile
	_saved_active = RunManager.is_run_active
	_saved_committed = RunManager._rewards_committed


func after_each() -> void:
	SaveSystem.data = _saved_data
	RunManager.active_dungeon_map = _saved_map
	RunManager.current_run_seed = _saved_seed
	RunManager.run_bits = _saved_bits
	RunManager.run_xp = _saved_xp
	RunManager.run_inventory = _saved_inventory
	RunManager.current_dungeon_tier = _saved_tier
	RunManager.dungeon_profile = _saved_profile
	RunManager.is_run_active = _saved_active
	RunManager._rewards_committed = _saved_committed
	RunManager.run_equipment_loot.clear()
	RunManager.run_mods_loot.clear()


func _map_data() -> Dictionary:
	var key := var_to_str(Vector2i.ZERO)
	return {
		"current_alert": 0.0,
		"total_nodes": 1,
		"nodes_done": 0,
		"current_coords": key,
		"width": 1,
		"height": 1,
		"node_data": {key: {"state": 1, "visited": true, "aware": true, "type": 0}},
		"terminal_memory": {},
		"encounter_memory": {},
		"reward_memory": {},
	}


func _run_data() -> Dictionary:
	return {
		"seed": 777,
		"tier": 0,
		"profile_path": PROFILE_PATH,
		"map_data": _map_data(),
		"run_bits": 44,
		"run_xp": 55,
		"run_inventory": {"mat_weap_1": 3},
		"run_equipment": [{
			"id": "pistol", "tier": 1, "rank": 2, "xp": 3,
			"inv_shared": 0, "inv_unique": 0, "inv_stats": {}, "mods": [],
		}],
		"run_mods": [{"id": "health_booster", "tier": 2}],
	}


func _set_sentinel_state() -> void:
	RunManager.current_run_seed = 111
	RunManager.run_bits = 12
	RunManager.run_xp = 13
	RunManager.run_inventory = {"sentinel": 9}
	RunManager.current_dungeon_tier = 4
	RunManager.dungeon_profile = null
	RunManager.is_run_active = false


func test_false_map_restore_preserves_pre_call_run_state() -> void:
	_set_sentinel_state()
	var map_double := RestoreMapDouble.new()
	map_double.restore_result = false
	RunManager.active_dungeon_map = map_double
	SaveSystem.data = {"active_run": _run_data()}

	assert_false(await RunManager.restore_run())
	assert_eq(RunManager.current_run_seed, 111)
	assert_eq(RunManager.run_bits, 12)
	assert_eq(RunManager.run_xp, 13)
	assert_eq(RunManager.run_inventory, {"sentinel": 9})
	assert_eq(RunManager.current_dungeon_tier, 4)
	assert_null(RunManager.dungeon_profile)
	assert_false(RunManager.is_run_active)
	map_double.free()


func test_true_map_restore_commits_normalized_run_fields() -> void:
	_set_sentinel_state()
	var map_double := RestoreMapDouble.new()
	map_double.restore_result = true
	RunManager.active_dungeon_map = map_double
	SaveSystem.data = {"active_run": _run_data()}
	assert_true(RunManager.begin_reward_commit())

	assert_true(await RunManager.restore_run())
	assert_true(RunManager.begin_reward_commit())
	assert_eq(RunManager.current_run_seed, 777)
	assert_eq(RunManager.run_bits, 44)
	assert_eq(RunManager.run_xp, 55)
	assert_eq(RunManager.run_inventory, {"mat_weap_1": 3})
	assert_eq(RunManager.current_dungeon_tier, DungeonRules.MIN_DUNGEON_TIER)
	assert_true(RunManager.dungeon_profile is DungeonProfile)
	assert_true(RunManager.is_run_active)
	assert_eq(RunManager.run_equipment_loot.size(), 1)
	assert_true(RunManager.run_equipment_loot[0] is Equipment)
	assert_eq(RunManager.run_mods_loot.size(), 1)
	assert_true(RunManager.run_mods_loot[0] is EquipmentMod)
	assert_eq(map_double.received_data, SaveSystem.data.active_run.map_data)
	map_double.free()
