# RunManager.gd
extends Node

enum RunResult { SUCCESS, RETREAT, DEFEAT }

var active_dungeon_map: DungeonMap = null
var is_run_active: bool = false
var current_dungeon_tier: int = 1
var current_run_seed: int = 0
var run_bits: int = 0
var run_xp: int = 0

var party_roster: Array[HeroData]:
	get:
		return SaveSystem.party_roster

func add_run_xp(amount: int):
	run_xp += amount

func add_run_bits(amount: int):
	run_bits += amount

func get_loot_scalar() -> float:
	var scalar = 1.0 + ((current_dungeon_tier - 1) * 0.25)

	# 2. (Future-Proofing) Add Party Level Logic here later
	# var avg_level = _get_average_party_level()
	# scalar += avg_level * 0.1

	return scalar

func get_run_save_data() -> Dictionary:
	if not active_dungeon_map: return {}

	return {
		"seed": current_run_seed,
		"run_bits": run_bits,
		"run_xp": run_xp,
		"tier": current_dungeon_tier,
		"map_data": active_dungeon_map.get_save_data()
	}

func restore_run():
	var run_data = SaveSystem.data.get("active_run")

	if not run_data:
		push_error("Tried to restore run, but SaveSystem data has no 'active_run'!")
		return

	current_run_seed = int(run_data.seed)
	run_bits = int(run_data.get("run_bits", 0))
	run_xp = int(run_data.get("run_xp", 0))
	current_dungeon_tier = int(run_data.get("tier", 1))
	is_run_active = true

	if active_dungeon_map:
		seed(current_run_seed)
		await active_dungeon_map.load_from_save_data(run_data.map_data)

func generate_battle_roster(node_type: MapNode.NodeType) -> Array[EnemyData]:
	var encounter = EncounterDatabase.get_random_encounter(current_dungeon_tier, node_type)
	return encounter.enemies

func spend_bits(amount: int) -> bool:
	if SaveSystem.bits >= amount:
		SaveSystem.bits -= amount
		return true
	return false

func get_bits() -> int:
	return SaveSystem.bits

func auto_save():
	# We only trigger the save if a run is happening.
	if is_run_active:
		SaveSystem.save_current_slot()

func commit_rewards(result: RunResult):
	var multiplier = 0.0

	match result:
		RunResult.SUCCESS: multiplier = 1.0
		RunResult.RETREAT: multiplier = 0.5
		RunResult.DEFEAT: multiplier = 0.0

	# Calculate Finals
	var final_bits = int(run_bits * multiplier)
	var final_xp = int(run_xp * multiplier)

	# Deposit
	if final_bits > 0:
		SaveSystem.bits += final_bits

	if final_xp > 0:
		SaveSystem.distribute_combat_xp(final_xp)

	# Reset Run State
	run_bits = 0
	run_xp = 0
	is_run_active = false

	# Save immediately
	SaveSystem.save_current_slot()
