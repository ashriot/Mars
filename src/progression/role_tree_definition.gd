class_name RoleTreeDefinition
extends RefCounted

var _role_id: String
var _version: int
var _root_id: String = ""
var _nodes: Array[ProgressionNodeDefinition] = []
var _nodes_by_id: Dictionary[String, ProgressionNodeDefinition] = {}
var _children_by_parent_id: Dictionary[String, Array] = {}

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
		return _nodes.duplicate()


func _init(tree_role_id: String, tree_version: int, tree_nodes: Array[ProgressionNodeDefinition]) -> void:
	_role_id = tree_role_id
	_version = tree_version
	_nodes = tree_nodes.duplicate()

	for node in _nodes:
		_nodes_by_id[node.id] = node
		if node.parent_id.is_empty():
			_root_id = node.id
		else:
			if not _children_by_parent_id.has(node.parent_id):
				_children_by_parent_id[node.parent_id] = []
			_children_by_parent_id[node.parent_id].append(node)

	for children: Array in _children_by_parent_id.values():
		children.sort_custom(_comes_before)


func get_node(node_id: String) -> ProgressionNodeDefinition:
	return _nodes_by_id.get(node_id)


func get_children(node_id: String) -> Array[ProgressionNodeDefinition]:
	var children: Array[ProgressionNodeDefinition] = []
	children.assign(_children_by_parent_id.get(node_id, []))
	return children


static func _comes_before(left: ProgressionNodeDefinition, right: ProgressionNodeDefinition) -> bool:
	if left.rank != right.rank:
		return left.rank < right.rank
	if left.column != right.column:
		return left.column < right.column
	return left.id < right.id
