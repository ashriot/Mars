extends GutTest


func test_effect_factories_construct_typed_immutable_values() -> void:
	var stat := ProgressionEffect.stat("ATK", 2)
	var action := ProgressionEffect.action("res://actions/burst.tres", 1)
	var passive := ProgressionEffect.passive("res://actions/steady.tres")
	var shift_action := ProgressionEffect.shift_action("res://actions/dash.tres")

	assert_eq(stat.type, ProgressionEffect.Type.STAT)
	assert_eq(stat.target, "ATK")
	assert_eq(stat.amount, 2)
	assert_eq(action.type, ProgressionEffect.Type.ACTION)
	assert_eq(passive.type, ProgressionEffect.Type.PASSIVE)
	assert_eq(shift_action.type, ProgressionEffect.Type.SHIFT_ACTION)
	assert_true(stat.is_valid)


func test_role_tree_exposes_anchor_and_two_starting_actions() -> void:
	var anchor := ProgressionNodeDefinition.role_anchor("gun.anchor", 1, 0)
	var first := ProgressionNodeDefinition.progression(
		"gun.root", "gun.anchor", 1, -1, 0,
		ProgressionEffect.action("res://data/heroes/asher/actions/double_tap.tres", 1), true,
	)
	var second := ProgressionNodeDefinition.progression(
		"gun.fusion_ammo", "gun.anchor", 1, 1, 0,
		ProgressionEffect.action("res://data/heroes/asher/actions/fusion_ammo.tres", 2), true,
	)
	var paid := ProgressionNodeDefinition.progression("gun.atk_1", "gun.anchor", 2, 0, 200, ProgressionEffect.stat("ATK", 1))
	var tree := RoleTreeDefinition.new("gun", 4, [anchor, first, second, paid])

	assert_true(tree.is_valid, tree.validation_error)
	assert_eq(tree.root_id, "gun.anchor")
	assert_eq(tree.starting_node_ids, ["gun.root", "gun.fusion_ammo"])
	assert_true(anchor.is_structural)
	assert_eq(anchor.kind, ProgressionNodeDefinition.NodeKind.ROLE_ANCHOR)
	assert_null(anchor.effect)
	assert_true(first.starting_owned)
	assert_false(paid.starting_owned)


func test_starting_node_ids_are_returned_defensively() -> void:
	var tree := _valid_tree()
	var exposed: Array[String] = tree.starting_node_ids
	exposed.clear()
	assert_eq(tree.starting_node_ids, ["gun.root", "gun.fusion_ammo"])


func test_anchor_rejects_effect_cost_and_ownership_semantics() -> void:
	var effect_anchor := ProgressionNodeDefinition.new(
		ProgressionNodeDefinition.NodeKind.ROLE_ANCHOR, "gun.anchor", "", 1, 0, 0,
		ProgressionEffect.stat("ATK", 1), false,
	)
	var cost_anchor := ProgressionNodeDefinition.new(
		ProgressionNodeDefinition.NodeKind.ROLE_ANCHOR, "gun.anchor", "", 1, 0, 1, null, false,
	)
	var owned_anchor := ProgressionNodeDefinition.new(
		ProgressionNodeDefinition.NodeKind.ROLE_ANCHOR, "gun.anchor", "", 1, 0, 0, null, true,
	)
	assert_false(effect_anchor.is_valid)
	assert_false(cost_anchor.is_valid)
	assert_false(owned_anchor.is_valid)


func test_tree_rejects_two_anchors() -> void:
	var nodes := _valid_nodes()
	nodes.append(ProgressionNodeDefinition.role_anchor("gun.other_anchor", 1, 0))
	assert_false(RoleTreeDefinition.new("gun", 1, nodes).is_valid)


func test_tree_requires_exactly_two_starting_nodes() -> void:
	var fewer := _valid_nodes()
	fewer.remove_at(2)
	var more := _valid_nodes()
	more.append(_starting("gun.third", 3, 2))
	assert_false(RoleTreeDefinition.new("gun", 1, fewer).is_valid)
	assert_false(RoleTreeDefinition.new("gun", 1, more).is_valid)


func test_tree_rejects_invalid_starting_node_shape() -> void:
	var rank_nodes := _valid_nodes()
	rank_nodes[1] = ProgressionNodeDefinition.progression("gun.root", "gun.anchor", 2, -1, 0, ProgressionEffect.action("res://action.tres", 1), true)
	var effect_nodes := _valid_nodes()
	effect_nodes[1] = ProgressionNodeDefinition.progression("gun.root", "gun.anchor", 1, -1, 0, ProgressionEffect.stat("ATK", 1), true)
	var cost_nodes := _valid_nodes()
	cost_nodes[1] = ProgressionNodeDefinition.progression("gun.root", "gun.anchor", 1, -1, 1, ProgressionEffect.action("res://action.tres", 1), true)
	var parent_nodes := _valid_nodes()
	parent_nodes[1] = ProgressionNodeDefinition.progression("gun.root", "gun.paid", 1, -1, 0, ProgressionEffect.action("res://action.tres", 1), true)
	assert_false(RoleTreeDefinition.new("gun", 1, rank_nodes).is_valid)
	assert_false(RoleTreeDefinition.new("gun", 1, effect_nodes).is_valid)
	assert_false(RoleTreeDefinition.new("gun", 1, cost_nodes).is_valid)
	assert_false(RoleTreeDefinition.new("gun", 1, parent_nodes).is_valid)


func test_tree_rejects_duplicate_starting_action_slots() -> void:
	var nodes := _valid_nodes()
	nodes[2] = _starting("gun.fusion_ammo", 1, 1)
	assert_false(RoleTreeDefinition.new("gun", 1, nodes).is_valid)


func test_progression_nodes_require_effect_and_positive_cost_unless_starting_owned() -> void:
	assert_false(ProgressionNodeDefinition.progression("gun.bad", "gun.anchor", 2, 0, 100, null).is_valid)
	assert_false(ProgressionNodeDefinition.progression("gun.free", "gun.anchor", 2, 0, 0, ProgressionEffect.stat("ATK", 1)).is_valid)
	assert_true(_starting("gun.root", 1, -1).is_valid)


func test_tree_rejects_duplicate_ids_and_returns_sorted_children() -> void:
	var nodes := _valid_nodes()
	nodes.append(ProgressionNodeDefinition.progression("gun.paid", "gun.anchor", 3, 2, 100, ProgressionEffect.stat("ATK", 1)))
	assert_false(RoleTreeDefinition.new("gun", 1, nodes).is_valid)

	var tree := _valid_tree()
	assert_eq(tree.get_children("gun.anchor").map(func(node): return node.id), ["gun.root", "gun.fusion_ammo", "gun.paid"])
	var children := tree.get_children("gun.anchor")
	children.clear()
	assert_eq(tree.get_children("gun.anchor").size(), 3)


func _valid_tree() -> RoleTreeDefinition:
	return RoleTreeDefinition.new("gun", 1, _valid_nodes())


func _valid_nodes() -> Array[ProgressionNodeDefinition]:
	return [
		ProgressionNodeDefinition.role_anchor("gun.anchor", 1, 0),
		_starting("gun.root", 1, -1),
		_starting("gun.fusion_ammo", 2, 1),
		ProgressionNodeDefinition.progression("gun.paid", "gun.anchor", 2, 0, 100, ProgressionEffect.stat("ATK", 1)),
	]


func _starting(id: String, slot: int, column: int) -> ProgressionNodeDefinition:
	return ProgressionNodeDefinition.progression(
		id, "gun.anchor", 1, column, 0, ProgressionEffect.action("res://action.tres", slot), true,
	)
