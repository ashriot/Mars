# SaveSystem.gd
extends Node

const SAVE_DIR = "user://saves/"
const SLOT_PREFIX = "slot_"
const SLOT_EXT = ".json"

var current_slot_index: int = 1

# --- GLOBAL DATA ---
var bits: int = 0
var party_roster: Array[HeroData] = []
var total_lifetime_xp: int = 0

# The Dictionary is just for serialization now
var data: Dictionary = {}

func _ready():
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

# --- FILE I/O ---

func save_current_slot():
	save_game(current_slot_index)

func save_game(slot_index: int):
	# 1. Update Dictionary with Live Data
	if RunManager.is_run_active:
		data["active_run"] = RunManager.get_run_save_data()
	else:
		data["active_run"] = null

	# Serialize Heroes
	var hero_dicts = []
	for hero in party_roster:
		hero_dicts.append(hero.get_save_data())
	data["heroes"] = hero_dicts

	data["bits"] = bits
	data["total_lifetime_xp"] = total_lifetime_xp

	# 2. Write to disk
	var path = _get_slot_path(slot_index)
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
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

		# Restore Bits (THIS IS THE FIX)
		bits = int(data.get("bits", 0))
		total_lifetime_xp = int(data.get("total_lifetime_xp", 0))

		# Restore Party
		party_roster.clear()
		var saved_heroes = data.get("heroes", [])
		for hero_dict in saved_heroes:
			var hero_id = hero_dict.get("hero_id", "asher")
			var path_to_base = "res://data/heroes/" + hero_id + "/" + hero_id + ".tres"

			if ResourceLoader.exists(path_to_base):
				var hero_obj = load(path_to_base).duplicate()
				hero_obj.load_from_save_data(hero_dict)
				party_roster.append(hero_obj)

		return true
	return false

func start_new_campaign(slot_index: int):
	current_slot_index = slot_index

	# Default Party
	party_roster.clear()
	party_roster.append(load("res://data/heroes/asher/asher.tres").duplicate())
	party_roster.append(load("res://data/heroes/echo/echo.tres").duplicate())
	#party_roster.append(load("res://data/heroes/sands/sands.tres").duplicate())

	# Default Bits
	bits = 100

	# Initialize clean data dict
	data = {
		"meta_data": { "playtime": 0, "location": "HUB" },
		"active_run": null
	}

	save_game(slot_index)

func _get_slot_path(index: int) -> String:
	return SAVE_DIR + SLOT_PREFIX + str(index) + SLOT_EXT

func has_save(index: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(index))

func distribute_combat_xp(amount: int):
	print("Party gained ", amount, " XP.")

	total_lifetime_xp += amount

	for hero in party_roster:
		hero.gain_xp(amount)

# --- PARTY MANAGEMENT (The Catch-Up Mechanic) ---
func unlock_hero(hero_id: String):
	var path_to_base = "res://data/heroes/" + hero_id + "/" + hero_id + ".tres"
	if ResourceLoader.exists(path_to_base):
		var new_hero = load(path_to_base).duplicate()
		new_hero.current_xp = total_lifetime_xp
		party_roster.append(new_hero)
		print(new_hero.hero_name, " joined the party with ", total_lifetime_xp, " XP!")
