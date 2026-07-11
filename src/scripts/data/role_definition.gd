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
