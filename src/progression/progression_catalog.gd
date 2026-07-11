class_name ProgressionCatalog
extends RefCounted

var errors: Array[ProgressionContentError] = []
var _roles: Dictionary[String, RoleTreeDefinition] = {}


func load_directory(path: String) -> Error:
	var directory := DirAccess.open(path)
	if directory == null:
		errors = [ProgressionContentError.new(path, "", "directory", "Could not open directory.")]
		return ERR_CANT_OPEN
	var filenames: Array[String] = []
	for filename: String in directory.get_files():
		if filename.get_extension().to_lower() == "json":
			filenames.append(filename)
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
		errors = next_errors
		return ERR_INVALID_DATA
	_roles = next_roles
	errors.clear()
	return OK


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
	var effect_names := ["stat", "action", "passive", "shift_action"]
	for node: ProgressionNodeDefinition in tree.nodes:
		total_xp += node.cost
		maximum_rank = maxi(maximum_rank, node.rank)
		effect_counts[effect_names[node.effect.type]] += 1
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
