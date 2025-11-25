extends Resource
class_name RoleData

var source_definition: RoleDefinition

var role_name: String:
	get: return source_definition.role_name
var description: String:
	get: return source_definition.description
var icon: Texture:
	get: return source_definition.icon
var color: Color:
	get: return source_definition.color

# Base actions (unlocked at specific ranks)
@export var shift_action: Action
@export var passive: Action
@export var actions: Array[Action]


func clear_combat_data():
	shift_action = null
	passive = null
	actions.clear()
