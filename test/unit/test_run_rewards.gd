extends GutTest

const RunManagerScript = preload("res://src/singletons/run_manager.gd")

var _saved_bits: int
var _saved_inventory: Dictionary
var _saved_equipment: Array[Equipment]
var _saved_mods: Array[EquipmentMod]
var _saved_data: Dictionary
var _saved_roster: Array[HeroData]
var _saved_total_xp: int
var _saved_slot: int
var _saved_run_bits: int
var _saved_run_xp: int
var _saved_run_inventory: Dictionary
var _saved_run_equipment: Array[Equipment]
var _saved_run_mods: Array[EquipmentMod]
var _saved_active: bool
var _saved_map: DungeonMap
var _saved_profile: DungeonProfile
var _saved_committed: bool
var _test_map: DungeonMap


func before_each() -> void:
	_saved_bits = SaveSystem.bits
	_saved_inventory = SaveSystem.inventory
	_saved_equipment.assign(SaveSystem.inventory_equipment)
	_saved_mods.assign(SaveSystem.inventory_mods)
	_saved_data = SaveSystem.data
	_saved_roster.assign(SaveSystem.party_roster)
	_saved_total_xp = SaveSystem.total_lifetime_xp
	_saved_slot = SaveSystem.current_slot_index
	_saved_run_bits = RunManager.run_bits
	_saved_run_xp = RunManager.run_xp
	_saved_run_inventory = RunManager.run_inventory
	_saved_run_equipment.assign(RunManager.run_equipment_loot)
	_saved_run_mods.assign(RunManager.run_mods_loot)
	_saved_active = RunManager.is_run_active
	_saved_map = RunManager.active_dungeon_map
	_saved_profile = RunManager.dungeon_profile
	_saved_committed = RunManager._rewards_committed

	SaveSystem.bits = 10
	SaveSystem.total_lifetime_xp = 0
	SaveSystem.inventory = {"existing": 2}
	SaveSystem.inventory_equipment.clear()
	SaveSystem.inventory_mods.clear()
	SaveSystem.party_roster.clear()
	SaveSystem.data = {"active_run": {"stale": true}}
	SaveSystem.current_slot_index = 987654
	RunManager.prepare_fresh_run()
	RunManager.is_run_active = true
	RunManager.run_bits = 101
	RunManager.run_xp = 0
	RunManager.run_inventory = {"mat_weap_1": 3, "mat_arm_1": 2}
	RunManager.run_equipment_loot.assign([load("res://data/equipment/weapons/pistol.tres").duplicate()])
	RunManager.run_mods_loot.assign([load("res://data/equipment/mods/health_booster.tres").duplicate()])
	_test_map = DungeonMap.new()
	RunManager.active_dungeon_map = _test_map
	RunManager.dungeon_profile = load("res://data/enemies/dungeon_profiles/first_alleyway.tres")


func after_each() -> void:
	if is_instance_valid(_test_map):
		_test_map.free()
	SaveSystem.bits = _saved_bits
	SaveSystem.total_lifetime_xp = _saved_total_xp
	SaveSystem.inventory = _saved_inventory
	SaveSystem.inventory_equipment.assign(_saved_equipment)
	SaveSystem.inventory_mods.assign(_saved_mods)
	SaveSystem.data = _saved_data
	SaveSystem.party_roster.assign(_saved_roster)
	SaveSystem.current_slot_index = _saved_slot
	RunManager.run_bits = _saved_run_bits
	RunManager.run_xp = _saved_run_xp
	RunManager.run_inventory = _saved_run_inventory
	RunManager.run_equipment_loot.assign(_saved_run_equipment)
	RunManager.run_mods_loot.assign(_saved_run_mods)
	RunManager.is_run_active = _saved_active
	RunManager.active_dungeon_map = _saved_map
	RunManager.dungeon_profile = _saved_profile
	RunManager._rewards_committed = _saved_committed


func test_reward_multiplier_matches_each_run_result() -> void:
	assert_eq(RunManagerScript.reward_multiplier(RunManager.RunResult.SUCCESS), 1.0)
	assert_eq(RunManagerScript.reward_multiplier(RunManager.RunResult.RETREAT), 0.5)
	assert_eq(RunManagerScript.reward_multiplier(RunManager.RunResult.DEFEAT), 0.0)


func test_final_reward_amount_truncates_fractional_xp_deterministically() -> void:
	assert_eq(RunManagerScript.final_reward_amount(101, RunManager.RunResult.SUCCESS), 101)
	assert_eq(RunManagerScript.final_reward_amount(101, RunManager.RunResult.RETREAT), 50)
	assert_eq(RunManagerScript.final_reward_amount(101, RunManager.RunResult.DEFEAT), 0)


func test_begin_reward_commit_allows_only_the_first_call() -> void:
	assert_true(RunManager.begin_reward_commit())
	assert_false(RunManager.begin_reward_commit())


func test_prepare_fresh_run_resets_reward_commit_guard() -> void:
	assert_true(RunManager.begin_reward_commit())
	RunManager.prepare_fresh_run()
	assert_true(RunManager.begin_reward_commit())


func test_success_banks_all_rewards_and_clears_temporary_state() -> void:
	RunManager.commit_rewards(RunManager.RunResult.SUCCESS)

	assert_eq(SaveSystem.bits, 111)
	assert_eq(SaveSystem.inventory, {"existing": 2, "mat_weap_1": 3, "mat_arm_1": 2})
	assert_eq(SaveSystem.inventory_equipment.size(), 1)
	assert_eq(SaveSystem.inventory_mods.size(), 1)
	_assert_run_finished_and_saved()


func test_retreat_banks_half_stack_rewards_and_no_equipment_or_mods() -> void:
	RunManager.commit_rewards(RunManager.RunResult.RETREAT)

	assert_eq(SaveSystem.bits, 60)
	assert_eq(SaveSystem.inventory, {"existing": 2, "mat_weap_1": 1, "mat_arm_1": 1})
	assert_eq(SaveSystem.inventory_equipment.size(), 0)
	assert_eq(SaveSystem.inventory_mods.size(), 0)
	_assert_run_finished_and_saved()


func test_defeat_banks_nothing_and_clears_temporary_state() -> void:
	RunManager.commit_rewards(RunManager.RunResult.DEFEAT)

	assert_eq(SaveSystem.bits, 10)
	assert_eq(SaveSystem.inventory, {"existing": 2})
	assert_eq(SaveSystem.inventory_equipment.size(), 0)
	assert_eq(SaveSystem.inventory_mods.size(), 0)
	_assert_run_finished_and_saved()


func test_duplicate_commit_does_not_deposit_twice() -> void:
	RunManager.commit_rewards(RunManager.RunResult.SUCCESS)
	RunManager.run_bits = 999
	RunManager.run_inventory = {"mat_weap_1": 99}
	RunManager.commit_rewards(RunManager.RunResult.SUCCESS)

	assert_eq(SaveSystem.bits, 111)
	assert_eq(SaveSystem.inventory.get("mat_weap_1"), 3)


func _assert_run_finished_and_saved() -> void:
	assert_false(RunManager.is_run_active)
	assert_eq(RunManager.run_bits, 0)
	assert_eq(RunManager.run_xp, 0)
	assert_eq(RunManager.run_inventory.size(), 0)
	assert_eq(RunManager.run_equipment_loot.size(), 0)
	assert_eq(RunManager.run_mods_loot.size(), 0)
	assert_null(RunManager.active_dungeon_map)
	assert_null(RunManager.dungeon_profile)
	assert_null(SaveSystem.data.get("active_run"))
