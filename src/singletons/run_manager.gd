# RunManager.gd
extends Node

var active_dungeon_map: DungeonMap = null
var is_run_active: bool = false
var current_run_seed: int = 0

# This allows other scripts to access the party without knowing about SaveSystem
var party_roster: Array[HeroData]:
	get:
		return SaveSystem.party_roster

func auto_save():
	# We only trigger the save if a run is happening.
	if is_run_active:
		SaveSystem.save_current_slot()

# --- CAPTURE DATA ---
func get_run_save_data() -> Dictionary:
	if not active_dungeon_map: return {}

	return {
		"seed": current_run_seed,
		"map_data": active_dungeon_map.get_save_data()
	}

# --- RESTORE DATA ---
func restore_run():
	var run_data = SaveSystem.data.get("active_run")

	if not run_data:
		push_error("Tried to restore run, but SaveSystem data has no 'active_run'!")
		return

	current_run_seed = int(run_data.seed)
	is_run_active = true

	if active_dungeon_map:
		seed(current_run_seed)
		await active_dungeon_map.load_from_save_data(run_data.map_data)

func add_bits(amount: int):
	SaveSystem.bits += amount
	# (Optional: Emit a signal here for UI updates)

func spend_bits(amount: int) -> bool:
	if SaveSystem.bits >= amount:
		SaveSystem.bits -= amount
		return true
	return false

func get_bits() -> int:
	return SaveSystem.bits
