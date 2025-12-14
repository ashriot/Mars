# ItemDatabase.gd (Autoload)
extends Node

var _item_registry: Dictionary = {}
var _equipment_ids: Array[String] = []
var _mod_ids: Array[String] = []

var icon_pistol = preload("res://assets/graphics/icons/equipment/pistol.png")
var icon_shotgun = preload("res://assets/graphics/icons/equipment/shotgun.png")
var icon_rifle = preload("res://assets/graphics/icons/equipment/rifle.png")
var icon_shirt = preload("res://assets/graphics/icons/equipment/shirt.png")
var icon_suit = preload("res://assets/graphics/icons/equipment/suit.png")
var icon_armor = preload("res://assets/graphics/icons/equipment/vest.png")

func _ready():
	_scan_for_items("res://data/equipment/")
	_scan_for_items("res://data/materials/")

func _scan_for_items(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_scan_for_items(path + "/" + file_name)
			elif file_name.ends_with(".tres") or file_name.ends_with(".remap"):
				var clean_name = file_name.replace(".remap", "")
				var full_path = path + "/" + clean_name
				var res = load(full_path)

				if "id" in res and res.id != "":
					if _item_registry.has(res.id):
						push_warning("ItemDatabase: Duplicate ID found: " + res.id)

					_item_registry[res.id] = res

					if res is Equipment:
						_equipment_ids.append(res.id)
					elif res is EquipmentMod:
						_mod_ids.append(res.id)

			file_name = dir.get_next()
	else:
		push_error("ItemDatabase: Could not open path: " + path)

func get_item_resource(id: String) -> Resource:
	if _item_registry.has(id):
		return _item_registry[id].duplicate()
	return null

func get_item_name(id: String) -> String:
	if not _item_registry.has(id):
		return id

	var res = _item_registry[id]

	# Prioritize 'item_name' for Equipment/Mods, 'name' for others
	if "item_name" in res:
		return res.item_name
	elif "name" in res:
		return res.name
	elif "mod_name" in res: # Assuming EquipmentMod has mod_name
		return res.mod_name

	return id

func get_item_icon(id: String) -> Texture2D:
	if not _item_registry.has(id):
		return null

	var res = _item_registry[id]
	if "icon" in res:
		return res.icon
	return null

func get_type_icon(item: Equipment) -> Texture2D:
	# 1. Try to find a specific SubType icon first
	match item.type:
		Equipment.EquipmentType.PISTOL: return icon_pistol
		Equipment.EquipmentType.SHOTGUN: return icon_shotgun
		Equipment.EquipmentType.RIFLE: return icon_rifle
		Equipment.EquipmentType.CLOTHES: return icon_shirt
		Equipment.EquipmentType.SUIT: return icon_suit
		Equipment.EquipmentType.VEST: return icon_armor

	return null

func get_random_equipment_id() -> String:
	if _equipment_ids.is_empty(): return ""
	return _equipment_ids.pick_random()

func get_random_mod_id() -> String:
	if _mod_ids.is_empty(): return ""
	return _mod_ids.pick_random()
