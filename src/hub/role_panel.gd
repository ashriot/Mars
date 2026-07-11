extends Panel
class_name RolePanel

signal panel_selected(role_panel)
signal purchase_requested(hero: HeroData, role_id: String, node_id: String)

@export var node_scene: PackedScene

@onready var header_label: Label = $Header/Label
@onready var role_name_label: Label = $Content/RoleName
@onready var xp_display: Label = $Content/XPDisplay
@onready var node_layer: Control = $Content/Nodes
@onready var content: Control = $Content

var def: RoleDefinition
var tree_definition: RoleTreeDefinition
var role_id: String = ""
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

func setup(role_def: RoleDefinition, tree: RoleTreeDefinition, hero: HeroData):
	def = role_def
	tree_definition = tree
	role_id = tree.role_id
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
	if tree_definition == null: return
	var min_rank := (page_index * 10) + 1
	var max_rank := min_rank + 9
	for node: ProgressionNodeDefinition in tree_definition.nodes:
		if node.rank >= min_rank and node.rank <= max_rank:
			_spawn_node(node)
	_update_tree_state()

func _clear_tree():
	generated_nodes.clear()
	for child in node_layer.get_children():
		child.queue_free()

func _spawn_node(data_node: ProgressionNodeDefinition) -> void:
	var ui_node := node_scene.instantiate() as SkillTreeNode
	node_layer.add_child(ui_node)
	ui_node.position = Vector2(expanded_x / 2.0 - 10.0 + data_node.column * HORIZONTAL_SPACING, ((data_node.rank - 1) % 10) * VERTICAL_SPACING)
	ui_node.position.x -= ui_node.size.x / 2
	ui_node.pivot_offset = ui_node.size / 2
	ui_node.setup(data_node, hero_data, tree_definition)
	ui_node.node_clicked.connect(_on_node_clicked)
	generated_nodes[data_node.id] = ui_node

func _update_tree_state():
	if tree_definition:
		for node: ProgressionNodeDefinition in tree_definition.nodes:
			if generated_nodes.has(node.id):
				_update_node_state(node)


func refresh_progression_state() -> void:
	if not hero_data:
		return
	_refresh_xp_ui()
	_update_tree_state()


func _update_node_state(node: ProgressionNodeDefinition) -> void:
	var progress: HeroRoleProgress = hero_data.role_progress.get(role_id)
	var is_owned := progress != null and node.id in progress.owned_node_ids
	var parent_unlocked := node.parent_id.is_empty() or (progress != null and node.parent_id in progress.owned_node_ids)
	var ui_node := generated_nodes[node.id] as SkillTreeNode
	ui_node.set_availability(not is_owned and parent_unlocked, hero_data.current_xp >= node.cost)
	ui_node._update_arrows(is_owned)
	ui_node._update_button_visuals(is_owned)

func _on_node_clicked(ui_node: SkillTreeNode):
	# --- 1. THE FIX: GUARD CLAUSE ---
	# If we somehow clicked a node while collapsed (or animating),
	# just expand the panel instead of buying.
	if not is_currently_expanded:
		panel_selected.emit(self)
		return
	# --------------------------------

	if ui_node.node_definition:
		purchase_requested.emit(hero_data, role_id, ui_node.node_definition.id)

func _refresh_xp_ui():
	# Use commafy if you have the util, or just str()
	if xp_display:
		xp_display.text = Utils.commafy(hero_data.current_xp) + " XP"
