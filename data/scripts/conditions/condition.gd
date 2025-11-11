extends Resource
class_name Condition

@export var condition_name: String
@export var is_buff: bool = true
@export var retarget: bool = false

@export var triggers: Array[Trigger]

@export var remove_on_triggers: Array[Trigger.TriggerType]
