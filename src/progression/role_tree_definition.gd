class_name RoleTreeDefinition
extends RefCounted

# Internal backing fields; supported callers use getter-only properties and
# defensive copies returned by nodes/get_children.
var _role_id: String
var _version: int
var _root_id: String = ""
var _starting_node_ids: Array[String] = []
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

var starting_node_ids: Array[String]:
	get:
		if not _is_valid:
			var empty: Array[String] = []
			return empty
		return _starting_node_ids.duplicate()

var nodes: Array[ProgressionNodeDefinition]:
	get:
		if not _is_valid:
			var empty: Array[ProgressionNodeDefinition] = []
			return empty
		return _nodes.duplicate()

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
	if roots[0].kind != ProgressionNodeDefinition.NodeKind.ROLE_ANCHOR:
		_invalidate("Role tree root must be a role anchor.")
		return
	_root_id = roots[0].id

	var starting_nodes: Array[ProgressionNodeDefinition] = []
	for node in _nodes:
		if not node.parent_id.is_empty() and not _nodes_by_id.has(node.parent_id):
			_invalidate("Parent '%s' does not exist for node '%s'." % [node.parent_id, node.id])
			return
		if node.starting_owned:
			starting_nodes.append(node)
	if starting_nodes.size() != 2:
		_invalidate("Role trees require exactly two starting-owned nodes.")
		return
	var starting_slots := {}
	for node in starting_nodes:
		if node.parent_id != _root_id or node.rank != 1 or node.cost != 0:
			_invalidate("Starting-owned nodes must be zero-cost rank 1 children of the role anchor.")
			return
		if node.effect == null or node.effect.type != ProgressionEffect.Type.ACTION:
			_invalidate("Starting-owned nodes require action effects.")
			return
		if starting_slots.has(node.effect.amount):
			_invalidate("Starting-owned action slots must be distinct.")
			return
		starting_slots[node.effect.amount] = true
	starting_nodes.sort_custom(_comes_before)
	for node in starting_nodes:
		_starting_node_ids.append(node.id)

	var reachable := {_root_id: true}
	var pending: Array[String] = [_root_id]
	while not pending.is_empty():
		var parent_id: String = pending.pop_front()
		for child: ProgressionNodeDefinition in _children_by_parent_id.get(parent_id, []):
			if not reachable.has(child.id):
				reachable[child.id] = true
				pending.append(child.id)
	if reachable.size() != _nodes.size():
		_invalidate("All progression nodes must be reachable from the role anchor.")
		return

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
	_starting_node_ids.clear()
	_nodes_by_id.clear()
	_children_by_parent_id.clear()


static func _comes_before(left: ProgressionNodeDefinition, right: ProgressionNodeDefinition) -> bool:
	if left.rank != right.rank:
		return left.rank < right.rank
	if left.column != right.column:
		return left.column < right.column
	return left.id < right.id
