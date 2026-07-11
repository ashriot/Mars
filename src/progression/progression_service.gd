class_name ProgressionService
extends RefCounted

var _catalog: ProgressionCatalog
var _rebuild: Callable
var _effect_validator: Callable


func _init(catalog: ProgressionCatalog, rebuild: Callable = Callable(), effect_validator: Callable = Callable()) -> void:
	_catalog = catalog
	_rebuild = rebuild if rebuild.is_valid() else ProgressionRebuilder.new(catalog).rebuild
	_effect_validator = effect_validator if effect_validator.is_valid() else _default_effect_validator


func purchase_node(hero: HeroData, role_id: String, node_id: String) -> ProgressionPurchaseResult:
	if hero == null:
		return _result(ProgressionPurchaseResult.Status.INVALID_HERO, role_id, node_id)
	if not role_id in hero.unlocked_role_ids:
		return _result(ProgressionPurchaseResult.Status.ROLE_LOCKED, role_id, node_id)
	var tree := _catalog.get_role(role_id) if _catalog != null else null
	if tree == null:
		return _result(ProgressionPurchaseResult.Status.NODE_NOT_FOUND, role_id, node_id)
	var node := tree.get_node(node_id)
	if node == null:
		return _result(ProgressionPurchaseResult.Status.NODE_NOT_FOUND, role_id, node_id)
	var progress: HeroRoleProgress = hero.role_progress.get(role_id)
	if progress != null and progress.content_revision != tree.version:
		return _result(ProgressionPurchaseResult.Status.REVISION_MISMATCH, role_id, node_id)
	if progress != null and node_id in progress.owned_node_ids:
		return _result(ProgressionPurchaseResult.Status.ALREADY_OWNED, role_id, node_id)
	if not node.parent_id.is_empty() and (progress == null or not node.parent_id in progress.owned_node_ids):
		return _result(ProgressionPurchaseResult.Status.PREREQUISITE_LOCKED, role_id, node_id)
	if hero.current_xp < node.cost:
		return _result(ProgressionPurchaseResult.Status.INSUFFICIENT_XP, role_id, node_id)
	if not _effect_validator.call(node.effect):
		return _result(ProgressionPurchaseResult.Status.INVALID_EFFECT, role_id, node_id)

	# Capture the exact persisted purchase state before the tentative commit.
	var previous_xp := hero.current_xp
	var previous_progress := progress
	var previous_stats := hero.stats
	var previous_stats_values := _snapshot_stats(hero.stats)
	var previous_battle_roles := hero.battle_roles
	var previous_battle_role_values := hero.battle_roles.duplicate()
	var previous_role_states := _snapshot_role_states(hero.battle_roles)

	# Commit only after every rejection path has been evaluated.
	if progress == null:
		progress = HeroRoleProgress.new(tree.version)
	else:
		progress = HeroRoleProgress.new(progress.content_revision, progress.owned_node_ids, progress.xp_paid_by_node)
	hero.role_progress[role_id] = progress
	hero.current_xp -= node.cost
	progress.owned_node_ids.append(node.id)
	progress.xp_paid_by_node[node.id] = node.cost
	progress.content_revision = tree.version
	var rebuild_result: Variant = _rebuild.call(hero)
	if not _rebuild_succeeded(rebuild_result):
		hero.current_xp = previous_xp
		_restore_derived_state(hero, previous_stats, previous_stats_values, previous_battle_roles, previous_battle_role_values, previous_role_states)
		if previous_progress == null:
			hero.role_progress.erase(role_id)
		else:
			hero.role_progress[role_id] = previous_progress
		return _result(ProgressionPurchaseResult.Status.INVALID_EFFECT, role_id, node_id)
	return ProgressionPurchaseResult.new(ProgressionPurchaseResult.Status.PURCHASED, role_id, node_id, node.cost, tree.version, hero, hero.current_xp)


func _result(status: ProgressionPurchaseResult.Status, role_id: String, node_id: String, paid: int = 0, revision: int = 0) -> ProgressionPurchaseResult:
	return ProgressionPurchaseResult.new(status, role_id, node_id, paid, revision)


func _default_effect_validator(effect: ProgressionEffect) -> bool:
	return effect != null and effect.is_valid


func _rebuild_succeeded(result: Variant) -> bool:
	if result == null:
		return true
	if result is bool:
		return result
	if result is ProgressionRebuilder.RebuildResult:
		return result.success
	return false


func _snapshot_stats(stats: ActorStats) -> Dictionary:
	if stats == null:
		return {}
	return {
		"actor_name": stats.actor_name, "max_hp": stats.max_hp,
		"starting_guard": stats.starting_guard, "starting_focus": stats.starting_focus,
		"attack": stats.attack, "psyche": stats.psyche, "overload": stats.overload,
		"speed": stats.speed, "aim": stats.aim, "precision": stats.precision,
		"kinetic_defense": stats.kinetic_defense, "energy_defense": stats.energy_defense,
	}


func _snapshot_role_states(roles: Dictionary) -> Dictionary:
	var snapshots := {}
	for role_id in roles:
		var role: Variant = roles[role_id]
		if role is RoleData:
			snapshots[role_id] = {
				"source_definition": role.source_definition,
				"actions": role.actions.duplicate(),
				"passive": role.passive,
				"shift_action": role.shift_action,
			}
	return snapshots


func _restore_derived_state(hero: HeroData, previous_stats: ActorStats, previous_values: Dictionary, previous_roles: Dictionary, previous_role_values: Dictionary, previous_role_states: Dictionary) -> void:
	if previous_stats != null:
		previous_stats.actor_name = previous_values.actor_name
		previous_stats.max_hp = previous_values.max_hp
		previous_stats.starting_guard = previous_values.starting_guard
		previous_stats.starting_focus = previous_values.starting_focus
		previous_stats.attack = previous_values.attack
		previous_stats.psyche = previous_values.psyche
		previous_stats.overload = previous_values.overload
		previous_stats.speed = previous_values.speed
		previous_stats.aim = previous_values.aim
		previous_stats.precision = previous_values.precision
		previous_stats.kinetic_defense = previous_values.kinetic_defense
		previous_stats.energy_defense = previous_values.energy_defense
	hero.stats = previous_stats
	for role_id in previous_role_states:
		var role: RoleData = previous_role_values[role_id]
		var state: Dictionary = previous_role_states[role_id]
		role.source_definition = state.source_definition
		role.actions.assign(state.actions)
		role.passive = state.passive
		role.shift_action = state.shift_action
	previous_roles.clear()
	previous_roles.merge(previous_role_values)
	hero.battle_roles = previous_roles
