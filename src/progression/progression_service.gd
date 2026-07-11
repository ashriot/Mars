class_name ProgressionService
extends RefCounted

var _catalog: ProgressionCatalog
var _rebuild: Callable


func _init(catalog: ProgressionCatalog, rebuild: Callable = Callable()) -> void:
	_catalog = catalog
	_rebuild = rebuild


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
	if node.effect == null or not node.effect.is_valid:
		return _result(ProgressionPurchaseResult.Status.INVALID_EFFECT, role_id, node_id)

	# Commit only after every rejection path has been evaluated.
	if progress == null:
		progress = HeroRoleProgress.new(tree.version)
		hero.role_progress[role_id] = progress
	hero.current_xp -= node.cost
	progress.owned_node_ids.append(node.id)
	progress.xp_paid_by_node[node.id] = node.cost
	progress.content_revision = tree.version
	if _rebuild.is_valid():
		_rebuild.call(hero)
	return _result(ProgressionPurchaseResult.Status.PURCHASED, role_id, node_id, node.cost, tree.version)


func _result(status: ProgressionPurchaseResult.Status, role_id: String, node_id: String, paid: int = 0, revision: int = 0) -> ProgressionPurchaseResult:
	return ProgressionPurchaseResult.new(status, role_id, node_id, paid, revision)
