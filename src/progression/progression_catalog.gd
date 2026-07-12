class_name ProgressionCatalog
extends RefCounted

var _errors: Array[ProgressionContentError] = []
var _roles: Dictionary[String, RoleTreeDefinition] = {}

var errors: Array[ProgressionContentError]:
	get:
		return _errors.duplicate()

var role_ids: Array[String]:
	get:
		return Array(_roles.keys(), TYPE_STRING, "", null)


static func from_validated_trees(trees: Array) -> ProgressionCatalog:
	var catalog := ProgressionCatalog.new()
	for candidate in trees:
		if not candidate is RoleTreeDefinition or not candidate.is_valid or catalog._roles.has(candidate.role_id):
			return null
		catalog._roles[candidate.role_id] = candidate
	return catalog


func load_directory(path: String) -> Error:
	var directory := _open_directory(path)
	if directory == null:
		_errors = [ProgressionContentError.new(path, "", "directory", "Could not open directory.")]
		return ERR_CANT_OPEN
	var filenames: Array[String] = []
	var collection_errors: Array[ProgressionContentError] = []
	_collect_json_files(path, "", filenames, collection_errors, directory)
	if not collection_errors.is_empty():
		_errors = collection_errors
		return ERR_CANT_OPEN
	filenames.sort()
	var next_roles: Dictionary[String, RoleTreeDefinition] = {}
	var next_errors: Array[ProgressionContentError] = []
	for filename: String in filenames:
		var file_path := path.path_join(filename)
		var result := ProgressionJsonLoader.load_file(file_path)
		if not result.errors.is_empty():
			next_errors.append_array(result.errors)
			continue
		if next_roles.has(result.tree.role_id):
			next_errors.append(ProgressionContentError.new(file_path, "", "role_id", "Duplicate role ID '%s'." % result.tree.role_id))
		else:
			next_roles[result.tree.role_id] = result.tree
	if not next_errors.is_empty():
		_errors = next_errors
		return ERR_INVALID_DATA
	_roles = next_roles
	_errors.clear()
	return OK


func _collect_json_files(root_path: String, relative_path: String, output: Array[String], collection_errors: Array[ProgressionContentError], opened_directory: DirAccess = null) -> void:
	var current_path := root_path.path_join(relative_path) if not relative_path.is_empty() else root_path
	var directory := opened_directory if opened_directory != null else _open_directory(current_path)
	if directory == null:
		collection_errors.append(ProgressionContentError.new(current_path, "", "directory", "Could not open directory."))
		return
	for filename: String in directory.get_files():
		if filename.get_extension().to_lower() == "json":
			output.append(relative_path.path_join(filename) if not relative_path.is_empty() else filename)
	var child_directories: Array[String] = []
	for child: String in directory.get_directories():
		child_directories.append(child)
	child_directories.sort()
	for child: String in child_directories:
		_collect_json_files(root_path, relative_path.path_join(child) if not relative_path.is_empty() else child, output, collection_errors)


func _open_directory(path: String) -> DirAccess:
	return DirAccess.open(path)


func get_role(role_id: String) -> RoleTreeDefinition:
	return _roles.get(role_id)


func get_summary(role_id: String) -> Dictionary:
	var tree := get_role(role_id)
	if tree == null:
		return {}
	var total_xp := 0
	var maximum_rank := 0
	var branch_count := 0
	var effect_counts := {"stat": 0, "action": 0, "passive": 0, "shift_action": 0}
	for node: ProgressionNodeDefinition in tree.nodes:
		total_xp += node.cost
		maximum_rank = maxi(maximum_rank, node.rank)
		if not node.is_structural:
			match node.effect.type:
				ProgressionEffect.Type.STAT: effect_counts.stat += 1
				ProgressionEffect.Type.ACTION: effect_counts.action += 1
				ProgressionEffect.Type.PASSIVE: effect_counts.passive += 1
				ProgressionEffect.Type.SHIFT_ACTION: effect_counts.shift_action += 1
		if tree.get_children(node.id).size() > 1:
			branch_count += 1
	return {
		"role_id": tree.role_id,
		"revision": tree.version,
		"node_count": tree.nodes.size(),
		"total_xp": total_xp,
		"maximum_rank": maximum_rank,
		"branch_count": branch_count,
		"effect_counts": effect_counts,
	}
