# RunManager.gd
extends Node

var active_dungeon_map: DungeonMap = null
var is_run_active: bool = false
var current_run_seed: int = 0

func auto_save():
	# Only save if we are actually in a run
	if is_run_active:
		SaveSystem.save_current_slot()

# --- CALLED BY SAVE SYSTEM ---
func get_run_save_data() -> Dictionary:
	if not active_dungeon_map: return {}

	return {
		"seed": current_run_seed,
		"map_data": active_dungeon_map.get_save_data(),
		# Add hero HP/Status here later
	}

# --- CALLED BY GAME SCENE ---
func restore_run():
	# We grab the data from the Global SaveSystem
	var run_data = SaveSystem.data.get("active_run")
	if not run_data:
		push_error("Tried to restore run, but no run data exists!")
		return

	current_run_seed = run_data.seed
	is_run_active = true

	if active_dungeon_map:
		seed(current_run_seed)
		await active_dungeon_map.load_from_save_data(run_data.map_data)
