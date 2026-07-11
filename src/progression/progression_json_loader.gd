class_name ProgressionJsonLoader
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const VALID_STATS := ["HP", "GRD", "FOC", "ATK", "PSY", "OVR", "SPD", "AIM", "PRE", "KIN_DEF", "NRG_DEF"]
const MIN_ACTION_SLOT := 1
const MAX_ACTION_SLOT := 4


class LoadResult extends RefCounted:
	var tree: RoleTreeDefinition
	var errors: Array[ProgressionContentError] = []

	func _init(loaded_tree: RoleTreeDefinition = null, load_errors: Array[ProgressionContentError] = []) -> void:
		tree = loaded_tree
		errors = load_errors.duplicate()


static func load_file(path: String) -> LoadResult:
	var errors: Array[ProgressionContentError] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_add_error(errors, path, "", "file", "Could not open file.")
		return LoadResult.new(null, errors)

	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		_add_error(errors, path, "", "json", "Invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return LoadResult.new(null, errors)
	if not parser.data is Dictionary:
		_add_error(errors, path, "", "document", "Top-level JSON value must be an object.")
		return LoadResult.new(null, errors)

	var document: Dictionary = parser.data
	_validate_document(path, document, errors)
	if not errors.is_empty():
		return LoadResult.new(null, errors)

	var nodes: Array[ProgressionNodeDefinition] = []
	for raw_node: Dictionary in document.nodes:
		var effect := _construct_effect(raw_node.effect)
		var parent_id := "" if raw_node.parent == null else str(raw_node.parent)
		nodes.append(ProgressionNodeDefinition.new(
			str(raw_node.id), parent_id, int(raw_node.rank), int(raw_node.column), int(raw_node.xp_cost), effect,
		))
	var tree := RoleTreeDefinition.new(str(document.role_id), int(document.content_revision), nodes)
	if not tree.is_valid:
		_add_error(errors, path, "", "nodes", tree.validation_error)
		return LoadResult.new(null, errors)
	return LoadResult.new(tree)


static func _validate_document(path: String, document: Dictionary, errors: Array[ProgressionContentError]) -> void:
	_validate_integer(path, "", document, "schema_version", errors)
	if _is_integer(document.get("schema_version")) and int(document.schema_version) != SUPPORTED_SCHEMA_VERSION:
		_add_error(errors, path, "", "schema_version", "Unsupported schema version: %s." % document.schema_version)
	_validate_nonempty_string(path, "", document, "role_id", errors)
	_validate_integer(path, "", document, "content_revision", errors)
	if _is_integer(document.get("content_revision")) and int(document.content_revision) <= 0:
		_add_error(errors, path, "", "content_revision", "Content revision must be positive.")
	if not document.has("nodes") or not document.nodes is Array:
		_add_error(errors, path, "", "nodes", "Nodes must be an array.")
		return

	var role_id := str(document.get("role_id", ""))
	var nodes_by_id := {}
	var roots: Array[String] = []
	for index in document.nodes.size():
		var raw: Variant = document.nodes[index]
		if not raw is Dictionary:
			_add_error(errors, path, "", "nodes.%d" % index, "Node must be an object.")
			continue
		var node: Dictionary = raw
		var node_id := str(node.get("id", ""))
		_validate_nonempty_string(path, node_id, node, "id", errors)
		if not node_id.is_empty() and not node_id.begins_with(role_id + "."):
			_add_error(errors, path, node_id, "id", "Node ID must belong to role namespace '%s'." % role_id)
		if nodes_by_id.has(node_id):
			_add_error(errors, path, node_id, "id", "Duplicate node ID.")
		elif not node_id.is_empty():
			nodes_by_id[node_id] = node
		if not node.has("parent") or (node.parent != null and not node.parent is String):
			_add_error(errors, path, node_id, "parent", "Parent must be null or a node ID string.")
		elif node.parent == null:
			roots.append(node_id)
		_validate_integer(path, node_id, node, "rank", errors)
		_validate_integer(path, node_id, node, "column", errors)
		_validate_integer(path, node_id, node, "xp_cost", errors)
		if _is_integer(node.get("xp_cost")) and int(node.xp_cost) <= 0:
			_add_error(errors, path, node_id, "xp_cost", "XP cost must be positive.")
		_validate_effect(path, node_id, node.get("effect"), errors)

	if roots.size() != 1:
		_add_error(errors, path, "", "nodes", "Role tree must have exactly one root; found %d." % roots.size())
	for node_id: String in nodes_by_id:
		var node: Dictionary = nodes_by_id[node_id]
		if node.get("parent") is String and not nodes_by_id.has(node.parent):
			_add_error(errors, path, node_id, "parent", "Parent '%s' does not exist in this role." % node.parent)
	_validate_topology(path, nodes_by_id, roots, errors)


static func _validate_topology(path: String, nodes_by_id: Dictionary, roots: Array[String], errors: Array[ProgressionContentError]) -> void:
	var cycle_nodes := {}
	for start_id: String in nodes_by_id:
		var positions := {}
		var chain: Array[String] = []
		var current := start_id
		while nodes_by_id.has(current):
			if positions.has(current):
				for index in range(int(positions[current]), chain.size()):
					cycle_nodes[chain[index]] = true
				break
			positions[current] = chain.size()
			chain.append(current)
			var parent: Variant = nodes_by_id[current].get("parent")
			if parent == null or not parent is String:
				break
			current = parent
	for node_id: String in cycle_nodes:
		_add_error(errors, path, node_id, "parent", "Parent relationship contains a cycle.")

	if roots.size() == 1 and nodes_by_id.has(roots[0]):
		var reachable := {roots[0]: true}
		var pending: Array[String] = [roots[0]]
		while not pending.is_empty():
			var parent_id: String = pending.pop_front()
			for node_id: String in nodes_by_id:
				if not reachable.has(node_id) and nodes_by_id[node_id].get("parent") == parent_id:
					reachable[node_id] = true
					pending.append(node_id)
		for node_id: String in nodes_by_id:
			if not reachable.has(node_id):
				_add_error(errors, path, node_id, "parent", "Node is unreachable from the root.")


static func _validate_effect(path: String, node_id: String, raw_effect: Variant, errors: Array[ProgressionContentError]) -> void:
	if not raw_effect is Dictionary:
		_add_error(errors, path, node_id, "effect", "Effect must be an object.")
		return
	var effect: Dictionary = raw_effect
	if not effect.get("type") is String:
		_add_error(errors, path, node_id, "effect.type", "Effect type must be a string.")
		return
	match effect.type:
		"stat":
			_validate_nonempty_string(path, node_id, effect, "stat", errors, "effect.")
			if effect.get("stat") is String and not effect.stat in VALID_STATS:
				_add_error(errors, path, node_id, "effect.stat", "Stat name must be recognized.")
			_validate_integer(path, node_id, effect, "amount", errors, "effect.")
			if _is_integer(effect.get("amount")) and int(effect.amount) == 0:
				_add_error(errors, path, node_id, "effect.amount", "Stat amount must be nonzero.")
		"action":
			_validate_action_resource(path, node_id, effect, errors)
			_validate_integer(path, node_id, effect, "slot", errors, "effect.")
			if _is_integer(effect.get("slot")) and (int(effect.slot) < MIN_ACTION_SLOT or int(effect.slot) > MAX_ACTION_SLOT):
				_add_error(errors, path, node_id, "effect.slot", "Action slot must be between 1 and 4.")
		"passive", "shift_action":
			_validate_action_resource(path, node_id, effect, errors)
		_:
			_add_error(errors, path, node_id, "effect.type", "Unknown effect type '%s'." % effect.type)


static func _validate_action_resource(path: String, node_id: String, effect: Dictionary, errors: Array[ProgressionContentError]) -> void:
	_validate_nonempty_string(path, node_id, effect, "resource", errors, "effect.")
	if not effect.get("resource") is String or effect.resource.is_empty():
		return
	if not effect.resource.begins_with("res://") or not ResourceLoader.exists(effect.resource):
		_add_error(errors, path, node_id, "effect.resource", "Resource path does not exist.")
		return
	var resource := ResourceLoader.load(effect.resource)
	if not resource is Action:
		_add_error(errors, path, node_id, "effect.resource", "Referenced resource must have the expected Action class.")


static func _construct_effect(effect: Dictionary) -> ProgressionEffect:
	match effect.type:
		"stat": return ProgressionEffect.stat(effect.stat, int(effect.amount))
		"action": return ProgressionEffect.action(effect.resource, int(effect.slot))
		"passive": return ProgressionEffect.passive(effect.resource)
		"shift_action": return ProgressionEffect.shift_action(effect.resource)
	return null


static func _validate_integer(path: String, node_id: String, object: Dictionary, key: String, errors: Array[ProgressionContentError], prefix: String = "") -> void:
	if not object.has(key) or not _is_integer(object[key]):
		_add_error(errors, path, node_id, prefix + key, "Field must be an integer.")


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, round(value)))


static func _validate_nonempty_string(path: String, node_id: String, object: Dictionary, key: String, errors: Array[ProgressionContentError], prefix: String = "") -> void:
	if not object.has(key) or not object[key] is String or object[key].is_empty():
		_add_error(errors, path, node_id, prefix + key, "Field must be a nonempty string.")


static func _add_error(errors: Array[ProgressionContentError], path: String, node_id: String, field: String, reason: String) -> void:
	errors.append(ProgressionContentError.new(path, node_id, field, reason))
