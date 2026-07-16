extends Panel
class_name RolePanel

signal panel_selected(role_panel)
signal purchase_requested(hero: HeroData, role_id: String, node_id: String)
signal node_focused(node_id: String)

@export var node_scene: PackedScene
@export var anchor_scene: PackedScene

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
var _current_page: int = 0
var _display_profile: int = DisplayProfileService.Profile.DESKTOP
var _role_shortcuts_enabled := false
var _chrome_active := true

var is_currently_expanded: bool = false

const VERTICAL_SPACING = 90
const VERTICAL_SPACING_COMPACT = 108
const NODE_MINIMUM_SIZE_DESKTOP := Vector2(250, 50)
const NODE_MINIMUM_SIZE_COMPACT := Vector2(250, 72)
const NODE_LAYER_TOP_COMPACT := 40.0
const NODE_LAYER_TOP_DESKTOP := -397.0
const NODE_LAYER_BOTTOM_DESKTOP := 443.0
const HORIZONTAL_SPACING = 300

func _ready():
	clip_contents = true
	custom_minimum_size.x = collapsed_x
	is_currently_expanded = false
	HubChrome.capture($Header)

func setup(role_def: RoleDefinition, tree: RoleTreeDefinition, hero: HeroData):
	def = role_def
	tree_definition = tree
	role_id = tree.role_id
	hero_data = hero

	header_label.text = def.role_id
	role_name_label.text = def.role_name
	modulate = def.color
	_refresh_xp_ui()


func apply_display_profile(profile: int) -> void:
	if _display_profile == profile:
		return
	_display_profile = profile
	var compact := profile == DisplayProfileService.Profile.COMPACT
	content.offset_bottom = 0.0 if compact else -9.0
	node_layer.anchor_top = 0.0 if compact else 0.5
	node_layer.anchor_bottom = 0.0 if compact else 0.5
	node_layer.offset_top = NODE_LAYER_TOP_COMPACT if compact else NODE_LAYER_TOP_DESKTOP
	node_layer.offset_bottom = NODE_LAYER_TOP_COMPACT + (NODE_LAYER_BOTTOM_DESKTOP - NODE_LAYER_TOP_DESKTOP) if compact else NODE_LAYER_BOTTOM_DESKTOP
	if tree_definition != null:
		render_tree(_current_page)

func _on_button_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		panel_selected.emit(self)

func set_expanded(is_expanded: bool, current_page: int, animate: bool = true):
	# Update State
	is_currently_expanded = is_expanded
	$Button.visible = not is_expanded
	set_role_shortcuts_enabled(_role_shortcuts_enabled)
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


func set_role_shortcuts_enabled(enabled: bool) -> void:
	_role_shortcuts_enabled = enabled
	$Content/PreviousRoleGlyph.visible = enabled and is_currently_expanded
	$Content/NextRoleGlyph.visible = enabled and is_currently_expanded


func set_chrome_active(active: bool) -> void:
	_chrome_active = active
	HubChrome.set_active($Header, active)
	for child in generated_nodes.values():
		if child is SkillTreeNode or child is RoleAnchorNode:
			child.set_chrome_active(active)

func render_tree(page_index: int):
	_current_page = page_index
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
	var ui_node: Control
	if data_node.kind == ProgressionNodeDefinition.NodeKind.ROLE_ANCHOR:
		ui_node = anchor_scene.instantiate() as Control
	else:
		ui_node = node_scene.instantiate() as SkillTreeNode
	node_layer.add_child(ui_node)
	if ui_node is SkillTreeNode:
		ui_node.apply_display_profile(_display_profile)
	else:
		ui_node.custom_minimum_size = NODE_MINIMUM_SIZE_COMPACT if _display_profile == DisplayProfileService.Profile.COMPACT else NODE_MINIMUM_SIZE_DESKTOP
	var vertical_spacing := VERTICAL_SPACING_COMPACT if _display_profile == DisplayProfileService.Profile.COMPACT else VERTICAL_SPACING
	ui_node.position = Vector2(expanded_x / 2.0 - 10.0 + data_node.column * HORIZONTAL_SPACING, ((data_node.rank - 1) % 10) * vertical_spacing)
	ui_node.position.x -= ui_node.size.x / 2
	ui_node.pivot_offset = ui_node.size / 2
	if data_node.kind == ProgressionNodeDefinition.NodeKind.ROLE_ANCHOR:
		ui_node.setup(def, tree_definition)
	else:
		ui_node.setup(data_node, hero_data, tree_definition)
		ui_node.node_clicked.connect(_on_node_clicked)
	ui_node.focus_entered.connect(_on_generated_node_focused.bind(data_node.id))
	generated_nodes[data_node.id] = ui_node
	if ui_node is SkillTreeNode or ui_node is RoleAnchorNode:
		ui_node.set_chrome_active(_chrome_active)


func _on_generated_node_focused(node_id: String) -> void:
	node_focused.emit(node_id)

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
	if node.is_structural:
		return
	var progress: HeroRoleProgress = hero_data.role_progress.get(role_id)
	var is_owned := node.starting_owned or (progress != null and node.id in progress.owned_node_ids)
	var parent := tree_definition.get_node(node.parent_id)
	var parent_unlocked := node.parent_id.is_empty() or (parent != null and parent.is_structural) or (progress != null and node.parent_id in progress.owned_node_ids)
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

	if ui_node.node_definition and ui_node.is_purchasable():
		purchase_requested.emit(hero_data, role_id, ui_node.node_definition.id)


func node_positions() -> Dictionary:
	var positions := {}
	for node_id: String in generated_nodes:
		var control := generated_nodes[node_id] as Control
		positions[node_id] = control.position + control.size * 0.5
	return positions

func _refresh_xp_ui():
	# Use commafy if you have the util, or just str()
	if xp_display:
		xp_display.text = Utils.commafy(hero_data.current_xp) + " XP"
