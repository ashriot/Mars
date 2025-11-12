extends Resource
class_name Condition

enum ConditionType { BUFF, DEBUFF, PASSIVE }

@export var condition_name: String
@export var condition_type: ConditionType = ConditionType.BUFF
@export var retarget: bool = false

@export var triggers: Array[Trigger]

@export var remove_on_triggers: Array[Trigger.TriggerType]
