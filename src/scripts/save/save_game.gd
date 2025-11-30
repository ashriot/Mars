extends Resource
class_name SaveGame

@export var save_name: String = "Save 1"
@export var timestamp: int = 0
@export var chapter: int = 1
@export var story_rank_cap: int = 5

# Hero data (Equipment + Role Progression)
@export var heroes: Array[HeroData] = []

# Inventory
@export var bits: int = 0
@export var inventory_weapons: Array[Equipment] = []
@export var inventory_armor: Array[Equipment] = []
@export var inventory_accessories: Array[Equipment] = []

# --- ACTIVE RUN DATA ---
# This holds the DungeonMap data if a run is in progress.
# If null or empty, the player is in the "Hub".
@export var active_run_data: Dictionary = {}

func save_to_file(slot: int):
	timestamp = int(Time.get_unix_time_from_system())
	var path = "user://save_%d.tres" % slot
	ResourceSaver.save(self, path)

static func load_from_file(slot: int) -> SaveGame:
	var path = "user://save_%d.tres" % slot
	if ResourceLoader.exists(path):
		return load(path) as SaveGame
	return null
