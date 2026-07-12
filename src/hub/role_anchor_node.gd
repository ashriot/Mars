extends Button
class_name RoleAnchorNode

var role_definition: RoleDefinition
var tree_definition: RoleTreeDefinition
var node_id: String = ""

@onready var icon_rect: TextureRect = $Panel/Icon
@onready var label: Label = $Label
@onready var description_label: Label = $Description
@onready var arrow_left: TextureRect = $Arrows/Left
@onready var arrow_down: TextureRect = $Arrows/Down
@onready var arrow_right: TextureRect = $Arrows/Right


func setup(role: RoleDefinition, tree: RoleTreeDefinition) -> void:
	role_definition = role
	tree_definition = tree
	node_id = tree.root_id
	focus_mode = Control.FOCUS_ALL
	set_meta("cursor_state", NavigationCursor.CursorState.INTERACT)
	icon_rect.texture = role.icon
	label.text = role.role_name
	description_label.text = role.description
	_update_arrows()


func _update_arrows() -> void:
	arrow_left.visible = false
	arrow_down.visible = false
	arrow_right.visible = false
	for child: ProgressionNodeDefinition in tree_definition.get_children(node_id):
		var arrow := arrow_down
		if child.column < 0:
			arrow = arrow_left
		elif child.column > 0:
			arrow = arrow_right
		arrow.visible = true
