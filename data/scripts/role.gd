extends Resource
class_name Role

@export var role_name: String = "New Role"
@export var color: Color
@export var shift_action: Action
@export var passive: Resource # You'll make a Passive.gd resource later
@export var actions: Array[Action] # Your 4 main actions
