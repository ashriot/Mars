extends Panel
class_name RolePanel

signal panel_selected(role_panel)

@export var node_scene: PackedScene

@onready var header_label: Label = $Header/Label
@onready var role_name_label: Label = $Content/RoleName
@onready var xp_display: Label = $Content/XPDisplay
@onready var node_layer: Control = $Content/Nodes
@onready var content: Control = $Content

var def: RoleDefinition
var hero_data: HeroData
var generated_nodes: Dictionary = {}

var collapsed_x: float = 290.0
var expanded_x: float = 900.0
var _size_tween: Tween

var is_currently_expanded: bool = false

const VERTICAL_SPACING = 90
const HORIZONTAL_SPACING = 300

func _ready():
	clip_contents = true
	custom_minimum_size.x = collapsed_x
	is_currently_expanded = false

func setup(role_def: RoleDefinition, hero: HeroData):
	def = role_def
	hero_data = hero

	header_label.text = def.role_id
	role_name_label.text = def.role_name
	modulate = def.color
	_refresh_xp_ui()

func _on_button_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		panel_selected.emit(self)

func set_expanded(is_expanded: bool, current_page: int, animate: bool = true):
	# Update State
	is_currently_expanded = is_expanded
	$Button.visible = not is_expanded
	var target_w = expanded_x if is_expanded else collapsed_x

	if not animate:
		custom_minimum_size.x = target_w
	else:
		if _size_tween and _size_tween.is_running():
			_size_tween.kill()
		_size_tween = create_tween().set_parallel(true)
		_size_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_size_tween.tween_property(self, "custom_minimum_size:x", target_w, 0.3)

	render_tree(current_page)

func render_tree(page_index: int):
	_clear_tree()
	if not def.root_node: return

	def.init_structure()

	var start_x = expanded_x / 2.0
	var start_pos = Vector2(start_x - 10.0, 0)

	_spawn_node_recursive(def.root_node, start_pos, 0, page_index)
	_update_tree_state()

func _clear_tree():
	generated_nodes.clear()
	for child in node_layer.get_children():
		child.queue_free()

func _spawn_node_recursive(data_node: RoleNode, pos: Vector2, depth: int, page_index: int):
	var min_rank = (page_index * 10) + 1
	var max_rank = min_rank + 9

	if data_node.rank >= min_rank and data_node.rank <= max_rank:
		var ui_node = node_scene.instantiate() as SkillTreeNode
		node_layer.add_child(ui_node)

		var rel_y_rank = (data_node.rank - 1) % 10
		var y_pos = (rel_y_rank * VERTICAL_SPACING)

		ui_node.position = Vector2(pos.x, y_pos)
		ui_node.position.x -= ui_node.size.x / 2
		ui_node.pivot_offset = ui_node.size / 2

		ui_node.setup(data_node, hero_data, def, depth)
		ui_node.node_clicked.connect(_on_node_clicked)

		generated_nodes[data_node] = ui_node

	if data_node.child_node:
		var next_pos = pos + Vector2(0, VERTICAL_SPACING)
		_spawn_node_recursive(data_node.child_node, next_pos, depth + 1, page_index)

	if data_node.left_node:
		var next_pos = pos + Vector2(-HORIZONTAL_SPACING, 0)
		_spawn_node_recursive(data_node.left_node, next_pos, depth, page_index)

	if data_node.right_node:
		var next_pos = pos + Vector2(HORIZONTAL_SPACING, 0)
		_spawn_node_recursive(data_node.right_node, next_pos, depth, page_index)

func _update_tree_state():
	if def and def.root_node:
		_check_availability_recursive(def.root_node, true)

func _check_availability_recursive(node: RoleNode, parent_unlocked: bool):
	var is_owned = node.generated_id in hero_data.unlocked_node_ids

	if generated_nodes.has(node):
		var ui_node = generated_nodes[node]
		var can_afford = hero_data.current_xp >= node.calculated_xp_cost
		var is_available = (not is_owned) and parent_unlocked

		ui_node.set_availability(is_available, can_afford)
		ui_node._update_arrows(is_owned)
		ui_node._update_button_visuals(is_owned)

	if node.child_node: _check_availability_recursive(node.child_node, is_owned)
	if node.left_node:  _check_availability_recursive(node.left_node, is_owned)
	if node.right_node: _check_availability_recursive(node.right_node, is_owned)

func _on_node_clicked(ui_node: SkillTreeNode):
	# --- 1. THE FIX: GUARD CLAUSE ---
	# If we somehow clicked a node while collapsed (or animating),
	# just expand the panel instead of buying.
	if not is_currently_expanded:
		panel_selected.emit(self)
		return
	# --------------------------------

	var data = ui_node.role_node_data

	if hero_data.current_xp >= data.calculated_xp_cost:
		hero_data.spend_xp(data.calculated_xp_cost)
		hero_data.unlock_node(data)
		hero_data.rebuild_battle_roles()

		AudioManager.play_sfx("terminal")
		_refresh_xp_ui()
		_update_tree_state()
	else:
		AudioManager.play_sfx("press")

func _refresh_xp_ui():
	# Use commafy if you have the util, or just str()
	if xp_display:
		xp_display.text = Utils.commafy(hero_data.current_xp) + " XP"
