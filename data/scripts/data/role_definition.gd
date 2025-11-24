extends Resource
class_name RoleDefinition

@export var role_id: String = "gun"
@export var role_name: String = "Gunslinger"
@export_multiline var description: String = ""
@export var icon: Texture
@export var color: Color = Color.WHITE

@export var root_node: RoleNode

func init_structure():
	root_node.initialize_tree(role_id, "1", 1, true)
