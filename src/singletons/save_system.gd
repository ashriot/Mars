# SaveSystem.gd
extends Node

const SAVE_DIR = "user://saves/"
const SLOT_PREFIX = "slot_"
const SLOT_EXT = ".json"

# The currently loaded "Campaign" data
var current_slot_index: int = 0
var data: Dictionary = {}

func _ready():
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

# --- FILE I/O ---

func save_current_slot():
	save_game(current_slot_index)

func save_game(slot_index: int):
	# 1. Update the "Active Run" data from RunManager if we are in a dungeon
	if RunManager.is_run_active:
		data["active_run"] = RunManager.get_run_save_data()
	else:
		data["active_run"] = null # Safely in town/hub

	# 2. Write to disk
	var path = _get_slot_path(slot_index)
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	#print("Game saved to Slot ", slot_index)

func load_game(slot_index: int) -> bool:
	var path = _get_slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var result = json.parse(file.get_as_text())

	if result == OK:
		data = json.get_data()
		current_slot_index = slot_index
		return true
	return false

# --- HELPERS ---

func start_new_campaign(slot_index: int):
	current_slot_index = slot_index
	# Initialize default JRPG state
	data = {
		"meta_data": {
			"playtime": 0,
			"location": "HUB"
		},
		"active_run": null
	}
	save_game(slot_index)

func _get_slot_path(index: int) -> String:
	return SAVE_DIR + SLOT_PREFIX + str(index) + SLOT_EXT

func has_save(index: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(index))
