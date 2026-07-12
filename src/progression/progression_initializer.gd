class_name ProgressionInitializer
extends RefCounted


static func initialize_role(hero: HeroData, role_id: String, catalog: ProgressionCatalog) -> bool:
	if hero == null or catalog == null or not role_id in hero.unlocked_role_ids:
		return false
	var tree := catalog.get_role(role_id)
	if tree == null:
		return false
	if hero.role_progress.has(role_id):
		return true
	var paid: Dictionary[String, int] = {}
	for node_id: String in tree.starting_node_ids:
		var node := tree.get_node(node_id)
		if node == null or not node.starting_owned or node.is_structural or node.cost != 0:
			return false
		paid[node_id] = 0
	hero.role_progress[role_id] = HeroRoleProgress.new(tree.version, tree.starting_node_ids, paid)
	return true


static func initialize_hero(hero: HeroData, catalog: ProgressionCatalog) -> ProgressionRebuilder.RebuildResult:
	if hero == null or catalog == null:
		return ProgressionRebuilder.RebuildResult.new(false, "A hero and progression catalog are required.")
	var original_progress := hero.role_progress.duplicate()
	for role_id: String in hero.unlocked_role_ids:
		if not initialize_role(hero, role_id, catalog):
			hero.role_progress = original_progress
			return ProgressionRebuilder.RebuildResult.new(false, "Could not initialize progression role '%s'." % role_id)
	var result := ProgressionRebuilder.new(catalog).rebuild(hero)
	if not result.success:
		hero.role_progress = original_progress
	return result
