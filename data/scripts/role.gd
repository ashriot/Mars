extends Resource
class_name Role

@export var role_name: String = "New Role"
@export_multiline var description: String = ""
@export var icon: Texture
@export var color: Color
@export var shift_action: Action
@export var passive: Action
@export var actions: Array[Action]
