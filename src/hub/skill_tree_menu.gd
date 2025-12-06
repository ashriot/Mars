extends Control
class_name SkillTreeMenu

@export var node_scene: PackedScene

@onready var node_layer: Control = $ScrollContainer/TreeContainer/Nodes
@onready var xp_label: Label = $XPDisplay

var current_hero: HeroData
var current_def: RoleDefinition
var generated_nodes: Dictionary = {}

const VERTICAL_SPACING = 100
const HORIZONTAL_SPACING = 350

func setup(hero: HeroData, role_def: RoleDefinition):
	current_hero = hero
	current_def = role_def

	_clear_tree()
	_refresh_xp_ui()

	if not role_def.root_node: return
	role_def.init_structure()

	# Spawn Recursively
	_spawn_node_recursive(role_def.root_node, Vector2(400, 50), 0)

	# Update Visuals
	_update_tree_state()

func _clear_tree():
	generated_nodes.clear()
	for child in node_layer.get_children():
		child.queue_free()

func _spawn_node_recursive(data_node: RoleNode, pos: Vector2, depth: int):
	var ui_node = node_scene.instantiate() as SkillTreeNode
	node_layer.add_child(ui_node)

	ui_node.position = pos
	ui_node.pivot_offset = ui_node.size / 2
	ui_node.setup(data_node, current_hero, depth)
	ui_node.node_clicked.connect(_on_node_clicked)

	generated_nodes[data_node] = ui_node

	# --- EXPLICIT LAYOUT ---

	# 1. Child (Down)
	if data_node.child_node:
		var next_pos = pos + Vector2(0, VERTICAL_SPACING)
		_spawn_node_recursive(data_node.child_node, next_pos, depth + 1)

	# 2. Left (Side)
	if data_node.left_node:
		var next_pos = pos + Vector2(-HORIZONTAL_SPACING, 0)
		# Important: Side nodes can have their OWN children that go DOWN from there.
		_spawn_node_recursive(data_node.left_node, next_pos, depth)

	# 3. Right (Side)
	if data_node.right_node:
		var next_pos = pos + Vector2(HORIZONTAL_SPACING, 0)
		_spawn_node_recursive(data_node.right_node, next_pos, depth)

func _update_tree_state():
	if current_def and current_def.root_node:
		_check_availability_recursive(current_def.root_node, true)

func _check_availability_recursive(node: RoleNode, parent_unlocked: bool):
	if not generated_nodes.has(node): return

	var ui_node: SkillTreeNode = generated_nodes[node]
	var is_owned = node.generated_id in current_hero.unlocked_node_ids
	var can_afford = current_hero.current_xp >= node.calculated_xp_cost

	# A node is available if you don't own it yet, but you DO own its parent
	var is_available = (not is_owned) and parent_unlocked

	# 1. Update Button State
	ui_node.set_availability(is_available, can_afford)

	# 2. Update Arrows
	# We update arrows here so they light up gold immediately when you buy the parent
	ui_node._update_arrows(current_hero, is_owned)
	ui_node._update_button_visuals(current_hero, is_owned)

	# 3. Recurse (Explicit Slots)
	# We pass 'is_owned' as the 'parent_unlocked' status for the children
	if node.child_node:
		_check_availability_recursive(node.child_node, is_owned)

	if node.left_node:
		_check_availability_recursive(node.left_node, is_owned)

	if node.right_node:
		_check_availability_recursive(node.right_node, is_owned)

func _on_node_clicked(ui_node: SkillTreeNode):
	var data = ui_node.role_node_data

	if current_hero.current_xp >= data.calculated_xp_cost:
		current_hero.spend_xp(data.calculated_xp_cost)
		current_hero.unlock_node(data)
		current_hero.rebuild_battle_roles()

		AudioManager.play_sfx("terminal")
		_refresh_xp_ui()
		_update_tree_state()
	else:
		AudioManager.play_sfx("press")

func _refresh_xp_ui():
	xp_label.text = "XP: %d" % current_hero.current_xp
