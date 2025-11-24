# RoleDatabase.gd (Autoload)
extends Node

# Key: role_id (String), Value: RoleDefinition (Resource)
var _role_registry: Dictionary = {}

func _ready():
	# Change this path to wherever you keep your Tree/Definition files
	_scan_for_roles("res://data/roles/")

func _scan_for_roles(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_scan_for_roles(path + "/" + file_name)
			elif file_name.ends_with(".tres") or file_name.ends_with(".remap"):
				var clean_name = file_name.replace(".remap", "")
				var res = load(path + "/" + clean_name)

				# Only register if it's a RoleDefinition
				if res is RoleDefinition and res.role_id != "":
					_role_registry[res.role_id] = res

			file_name = dir.get_next()
	else:
		push_error("RoleDatabase: Could not open path: " + path)

func get_role_definition(role_id: String) -> RoleDefinition:
	if _role_registry.has(role_id):
		return _role_registry[role_id]

	push_error("Role ID not found: " + role_id)
	return null
