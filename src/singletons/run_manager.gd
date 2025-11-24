# RunManager.gd
extends Node

@export var current_dungeon_tier: int = 1

var active_dungeon_map: DungeonMap = null
var is_run_active: bool = false
var current_run_seed: int = 0
var run_bits: int = 0

# This allows other scripts to access the party without knowing about SaveSystem
var party_roster: Array[HeroData]:
	get:
		return SaveSystem.party_roster

# --- BITS LOGIC ---
func add_run_bits(amount: int):
	run_bits += amount
	# Update UI Signal here

func get_loot_scalar() -> float:
	var scalar = 1.0 + ((current_dungeon_tier - 1) * 0.25)

	# 2. (Future-Proofing) Add Party Level Logic here later
	# var avg_level = _get_average_party_level()
	# scalar += avg_level * 0.1

	return scalar

# --- CAPTURE DATA ---
func get_run_save_data() -> Dictionary:
	if not active_dungeon_map: return {}

	return {
		"seed": current_run_seed,
		"run_bits": run_bits,
		"tier": current_dungeon_tier,
		"map_data": active_dungeon_map.get_save_data()
	}

# --- RESTORE DATA ---
func restore_run():
	var run_data = SaveSystem.data.get("active_run")

	if not run_data:
		push_error("Tried to restore run, but SaveSystem data has no 'active_run'!")
		return

	current_run_seed = int(run_data.seed)
	run_bits = int(run_data.get("run_bits", 0))
	current_dungeon_tier = int(run_data.get("tier", 1))
	is_run_active = true

	if active_dungeon_map:
		seed(current_run_seed)
		await active_dungeon_map.load_from_save_data(run_data.map_data)

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
