class_name ProgressionRebuilder
extends RefCounted

class RebuildResult:
	extends RefCounted

	var success: bool
	var error: String

	func _init(did_succeed: bool, failure_reason: String = "") -> void:
		success = did_succeed
		error = failure_reason

var _catalog: ProgressionCatalog
var _applier := ProgressionEffectApplier.new()


func _init(catalog: ProgressionCatalog) -> void:
	_catalog = catalog


func rebuild(hero: HeroData) -> RebuildResult:
	if hero == null or _catalog == null:
		return RebuildResult.new(false, "A hero and progression catalog are required.")
	var definitions: Dictionary = {}
	for definition: RoleDefinition in hero.role_definitions:
		definitions[definition.role_id] = definition
	var validation := _validate_saved_ownership(hero, definitions)
	if not validation.success:
		return validation

	var next_stats := hero.build_equipment_base_stats()
	var next_roles: Dictionary = {}

	for role_id: String in _catalog.role_ids:
		if not role_id in hero.unlocked_role_ids or not definitions.has(role_id):
			continue
		var role := RoleData.new()
		role.source_definition = definitions[role_id]
		var tree := _catalog.get_role(role_id)
		var progress: HeroRoleProgress = hero.role_progress.get(role_id)
		if progress != null:
			var ordered_nodes := tree.nodes
			ordered_nodes.sort_custom(_node_comes_before)
			for node: ProgressionNodeDefinition in ordered_nodes:
				if node.id in progress.owned_node_ids and not _applier.apply(node.effect, next_stats, role):
					return RebuildResult.new(false, "Invalid effect for owned node '%s'." % node.id)
		next_roles[role_id] = role

	hero.stats = next_stats
	hero.battle_roles = next_roles
	return RebuildResult.new(true)


func _validate_saved_ownership(hero: HeroData, definitions: Dictionary) -> RebuildResult:
	for role_id: String in hero.role_progress:
		var tree := _catalog.get_role(role_id)
		if tree == null:
			return RebuildResult.new(false, "Unknown progression role record '%s'." % role_id)
		if not definitions.has(role_id):
			return RebuildResult.new(false, "Progression role record '%s' has no hero role definition." % role_id)
		var progress: HeroRoleProgress = hero.role_progress[role_id]
		for node_id: String in progress.owned_node_ids:
			if tree.get_node(node_id) == null:
				return RebuildResult.new(false, "Progression role '%s' owns unknown node '%s'." % [role_id, node_id])
	return RebuildResult.new(true)


static func _node_comes_before(left: ProgressionNodeDefinition, right: ProgressionNodeDefinition) -> bool:
	if left.rank != right.rank:
		return left.rank < right.rank
	if left.column != right.column:
		return left.column < right.column
	return left.id < right.id
