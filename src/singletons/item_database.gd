# ItemDatabase.gd (Autoload)
extends Node

var _item_registry: Dictionary = {}
var _equipment_ids: Array[String] = []

func _ready():
	_scan_for_items("res://data/equipment/")
	_scan_for_items("res://data/materials/")

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
				if "id" in res and res.id != "":
					if _item_registry.has(res.id):
						push_warning("ItemDatabase: Duplicate ID found: " + res.id)

					_item_registry[res.id] = res
					if res is Equipment:
						_equipment_ids.append(res.id)

			file_name = dir.get_next()
	else:
		push_error("ItemDatabase: Could not open path: " + path)

func get_item_resource(id: String) -> Resource:
	if _item_registry.has(id):
		# Always duplicate to prevent shared state bugs
		return _item_registry[id].duplicate()
	return null


func get_item_name(id: String) -> String:
	if not _item_registry.has(id):
		return id

	var res = _item_registry[id]

	# Check for 'item_name' (Equipment) or 'name' (InventoryItem)
	if "item_name" in res:
		return res.item_name
	elif "name" in res:
		return res.name

	return id # Fallback to ID if no name property found

func get_item_icon(id: String) -> Texture2D:
	if not _item_registry.has(id):
		return null

	var res = _item_registry[id]
	if "icon" in res:
		return res.icon

	return null

func get_random_equipment_id() -> String:
	if _equipment_ids.is_empty(): return ""
	return _equipment_ids.pick_random()
