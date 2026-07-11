extends GutTest


func test_effect_factories_construct_typed_immutable_values() -> void:
	var stat := ProgressionEffect.stat("ATK", 2)
	var action := ProgressionEffect.action("res://actions/burst.tres", 1)
	var passive := ProgressionEffect.passive("res://actions/steady.tres", 3)
	var shift_action := ProgressionEffect.shift_action("res://actions/dash.tres", 4)

	assert_eq(stat.type, ProgressionEffect.Type.STAT)
	assert_eq(stat.target, "ATK")
	assert_eq(stat.amount, 2)
	assert_eq(action.type, ProgressionEffect.Type.ACTION)
	assert_eq(passive.type, ProgressionEffect.Type.PASSIVE)
	assert_eq(shift_action.type, ProgressionEffect.Type.SHIFT_ACTION)
	assert_eq(action.target, "res://actions/burst.tres")
	assert_eq(passive.amount, 3)


func test_node_definition_constructs_read_only_fields() -> void:
	var effect := ProgressionEffect.stat("DEF", 5)
	var node := ProgressionNodeDefinition.new("guard.root", "", 1, 2, 150, effect)

	assert_eq(node.id, "guard.root")
	assert_eq(node.parent_id, "")
	assert_eq(node.rank, 1)
	assert_eq(node.column, 2)
	assert_eq(node.cost, 150)
	assert_true(is_same(node.effect, effect))


func test_role_tree_indexes_nodes_without_deriving_identity() -> void:
	var root := ProgressionNodeDefinition.new("gun.root", "", 1, 0, 100, ProgressionEffect.stat("ATK", 1))
	var child := ProgressionNodeDefinition.new("gun.burst", "gun.root", 2, 1, 200, ProgressionEffect.action("res://example.tres", 1))
	var tree := RoleTreeDefinition.new("gun", 1, [child, root])

	assert_eq(tree.root_id, "gun.root")
	assert_true(is_same(tree.get_node("gun.burst"), child))
	assert_eq(tree.get_children("gun.root").map(func(node): return node.id), ["gun.burst"])


func test_children_are_sorted_deterministically_and_returned_as_a_copy() -> void:
	var root := ProgressionNodeDefinition.new("gun.root", "", 1, 0, 100, ProgressionEffect.stat("ATK", 1))
	var third := ProgressionNodeDefinition.new("gun.zeta", "gun.root", 3, 0, 100, ProgressionEffect.stat("ATK", 1))
	var second_b := ProgressionNodeDefinition.new("gun.beta", "gun.root", 2, 1, 100, ProgressionEffect.stat("ATK", 1))
	var second_a := ProgressionNodeDefinition.new("gun.alpha", "gun.root", 2, 1, 100, ProgressionEffect.stat("ATK", 1))
	var tree := RoleTreeDefinition.new("gun", 1, [third, second_b, root, second_a])

	var children := tree.get_children("gun.root")
	assert_eq(children.map(func(node): return node.id), ["gun.alpha", "gun.beta", "gun.zeta"])
	children.clear()
	assert_eq(tree.get_children("gun.root").map(func(node): return node.id), ["gun.alpha", "gun.beta", "gun.zeta"])


func test_layout_and_input_order_do_not_change_node_identity() -> void:
	var original := ProgressionNodeDefinition.new("gun.burst", "gun.root", 2, 1, 200, ProgressionEffect.stat("ATK", 1))
	var moved := ProgressionNodeDefinition.new("gun.burst", "gun.root", 9, 7, 200, ProgressionEffect.stat("ATK", 1))
	var original_tree := RoleTreeDefinition.new("gun", 1, [original])
	var moved_tree := RoleTreeDefinition.new("gun", 1, [moved])

	assert_eq(original_tree.get_node("gun.burst").id, moved_tree.get_node("gun.burst").id)
	assert_eq(original.id, "gun.burst")
	assert_eq(moved.id, "gun.burst")
