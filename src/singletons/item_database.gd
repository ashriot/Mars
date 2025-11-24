# ItemDatabase.gd (Autoload)
extends Node

# Dictionary mapping "sword_mk1" -> preload("res://.../sword_mk1.tres")
var _item_registry: Dictionary = {}

func _ready():
	_scan_for_items("res://data/equipment/")

# Automatically find all .tres files in your equipment folders
func _scan_for_items(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					# Recursively scan subfolders
					_scan_for_items(path + "/" + file_name)
			elif file_name.ends_with(".tres") or file_name.ends_with(".remap"):
				# Load the resource to check its ID
				# (In a huge game, we'd use a cache list, but for this size, loading is fine)
				var clean_name = file_name.replace(".remap", "")
				var full_path = path + "/" + clean_name
				var res = load(full_path)
				if res and "equipment_id" in res and res.equipment_id != "":
					_item_registry[res.equipment_id] = res

			file_name = dir.get_next()
	else:
		push_error("ItemDatabase: Could not open path: " + path)

# The Public API
func get_item_resource(id: String) -> Equipment:
	if _item_registry.has(id):
		# CRITICAL: Always duplicate!
		# If we don't, leveling up a sword in one save file
		# levels it up in the Editor and every other save file.
		return _item_registry[id].duplicate()

	push_error("Item ID not found: " + id)
	return null
