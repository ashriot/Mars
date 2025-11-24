extends Resource
class_name RoleData

@export var role_id: String = "gunslinger"
@export var role_name: String = "Gunslinger"
@export_multiline var description: String = ""
@export var icon: Texture
@export var color: Color

# Base actions (unlocked at specific ranks)
@export var shift_action: Action
@export var passive: Action
@export var actions: Array[Action]

func clear_combat_data():
	shift_action = null
	passive = null
	actions.clear()
