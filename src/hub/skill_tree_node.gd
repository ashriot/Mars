extends Button
class_name SkillTreeNode

signal node_clicked(node_ui)

enum NodeState { LOCKED, AVAILABLE, UNLOCKED }

var node_definition: ProgressionNodeDefinition
var tree_definition: RoleTreeDefinition
var state: NodeState = NodeState.LOCKED
var hero_data: HeroData

@onready var icon_rect: TextureRect = $Panel/Icon
@onready var owned_highlight: Panel = $Owned
@onready var label: Label = $Label
@onready var cost_label: Label = $XpCost
@onready var arrow_left: TextureRect = $Arrows/Left
@onready var arrow_down: TextureRect = $Arrows/Down
@onready var arrow_right: TextureRect = $Arrows/Right


func setup(node: ProgressionNodeDefinition, hero: HeroData, tree: RoleTreeDefinition):
	node_definition = node
	hero_data = hero
	tree_definition = tree
	focus_mode = Control.FOCUS_ALL
	_update_button_visuals(_is_owned(node.id))
	_update_arrows(_is_owned(node.id))


func set_availability(is_available: bool, can_afford: bool):
	if state == NodeState.UNLOCKED:
		set_meta("cursor_state", NavigationCursor.CursorState.INTERACT)
		return
	disabled = false
	if is_available:
		state = NodeState.AVAILABLE
		modulate = Color.WHITE if can_afford else Color.GAINSBORO
		modulate.a = 1.0
		cost_label.modulate = modulate
		set_meta("cursor_state", NavigationCursor.CursorState.UPGRADE if can_afford else NavigationCursor.CursorState.DISABLED)
	else:
		state = NodeState.LOCKED
		modulate = Color(1, 1, 1, 0.25)
		set_meta("cursor_state", NavigationCursor.CursorState.INTERACT)


func is_purchasable() -> bool:
	return state == NodeState.AVAILABLE and get_meta("cursor_state", NavigationCursor.CursorState.DISABLED) == NavigationCursor.CursorState.UPGRADE


func _update_button_visuals(is_owned: bool):
	cost_label.visible = not is_owned
	owned_highlight.visible = is_owned
	icon_rect.texture = null
	match node_definition.effect.type:
		ProgressionEffect.Type.STAT:
			label.text = node_definition.effect.target + "+%d" % node_definition.effect.amount
			if node_definition.effect.target in ["AIM", "KIN_DEF", "NRG_DEF"]: label.text += "%"
		ProgressionEffect.Type.ACTION, ProgressionEffect.Type.SHIFT_ACTION, ProgressionEffect.Type.PASSIVE:
			var resource := load(node_definition.effect.target) as Action
			label.text = resource.action_name if resource else "Unknown Action"
			icon_rect.texture = resource.icon if resource else null
	cost_label.text = str(node_definition.cost) + " XP"
	if is_owned:
		state = NodeState.UNLOCKED
		disabled = false
		modulate.a = 1.0
		cost_label.hide()
		set_meta("cursor_state", NavigationCursor.CursorState.INTERACT)


func _update_arrows(is_self_owned: bool):
	arrow_down.visible = false; arrow_left.visible = false; arrow_right.visible = false
	for child: ProgressionNodeDefinition in tree_definition.get_children(node_definition.id):
		var arrow: TextureRect = arrow_down
		if child.column < node_definition.column: arrow = arrow_left
		elif child.column > node_definition.column: arrow = arrow_right
		arrow.visible = true
		arrow.modulate = Color.WHITE if is_self_owned and _is_owned(child.id) else Color.GRAY


func _is_owned(node_id: String) -> bool:
	var progress: HeroRoleProgress = hero_data.role_progress.get(tree_definition.role_id)
	return progress != null and node_id in progress.owned_node_ids


func _pressed():
	node_clicked.emit(self)
