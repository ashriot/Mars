class_name RoleTreeDefinition
extends RefCounted

# Internal backing fields; supported callers use getter-only properties and
# defensive copies returned by nodes/get_children.
var _role_id: String
var _version: int
var _root_id: String = ""
var _nodes: Array[ProgressionNodeDefinition] = []
var _nodes_by_id: Dictionary[String, ProgressionNodeDefinition] = {}
var _children_by_parent_id: Dictionary[String, Array] = {}
var _is_valid: bool = false
var _validation_error: String = ""

var role_id: String:
	get:
		return _role_id

var version: int:
	get:
		return _version

var root_id: String:
	get:
		return _root_id

var nodes: Array[ProgressionNodeDefinition]:
	get:
		return _nodes.duplicate() if _is_valid else []

var is_valid: bool:
	get:
		return _is_valid

var validation_error: String:
	get:
		return _validation_error


func _init(tree_role_id: String, tree_version: int, tree_nodes: Array[ProgressionNodeDefinition]) -> void:
	_role_id = tree_role_id
	_version = tree_version
	_nodes = tree_nodes.duplicate()

	var roots: Array[ProgressionNodeDefinition] = []
	for node in _nodes:
		if node == null or not node.is_valid:
			_invalidate("Role trees require valid nodes.")
			return
		if _nodes_by_id.has(node.id):
			_invalidate("Duplicate progression node ID: %s" % node.id)
			return
		_nodes_by_id[node.id] = node
		if node.parent_id.is_empty():
			roots.append(node)
		else:
			if not _children_by_parent_id.has(node.parent_id):
				var new_children: Array[ProgressionNodeDefinition] = []
				_children_by_parent_id[node.parent_id] = new_children
			var children: Array[ProgressionNodeDefinition] = []
			children.assign(_children_by_parent_id[node.parent_id])
			children.append(node)
			_children_by_parent_id[node.parent_id] = children

	if roots.size() != 1:
		_invalidate("Role trees require exactly one root node.")
		return
	_root_id = roots[0].id

	for children: Array[ProgressionNodeDefinition] in _children_by_parent_id.values():
		children.sort_custom(_comes_before)
	_is_valid = true


func get_node(node_id: String) -> ProgressionNodeDefinition:
	return _nodes_by_id.get(node_id) if _is_valid else null


func get_children(node_id: String) -> Array[ProgressionNodeDefinition]:
	var children: Array[ProgressionNodeDefinition] = []
	if _is_valid:
		children.assign(_children_by_parent_id.get(node_id, []))
	return children


func _invalidate(error: String) -> void:
	_is_valid = false
	_validation_error = error
	_root_id = ""
	_nodes_by_id.clear()
	_children_by_parent_id.clear()


static func _comes_before(left: ProgressionNodeDefinition, right: ProgressionNodeDefinition) -> bool:
	if left.rank != right.rank:
		return left.rank < right.rank
	if left.column != right.column:
		return left.column < right.column
	return left.id < right.id
