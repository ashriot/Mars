extends Resource
class_name RoleDefinition

@export var role_id: String = ""
@export var role_name: String = ""
@export_multiline var description: String = ""

@export_group("Visuals")
@export var icon: Texture
@export var color: Color = Color.WHITE

@export_group("Kit Configuration")
@export var shift_action: Action
@export var passive: Action
@export var actions: Array[Action] = []

# DEPRECATED LEGACY-ONLY: authoritative topology is loaded by ProgressionSystem
# from data/progression/<hero>/<role_id>.json. Kept only so pre-migration
# HeroData code/resources remain loadable; Task 7 removes this field and method.
@export_group("Progression Tree")
@export var root_node: RoleNode

# DEPRECATED LEGACY-ONLY: new progression consumers resolve role_id in the
# ProgressionCatalog and must never initialize or traverse RoleNode resources.
func init_structure():
	if root_node:
		root_node.initialize_tree(role_id, "1", 1, true)
