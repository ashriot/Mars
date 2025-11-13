extends Resource
class_name Condition

enum ConditionType { BUFF, DEBUFF }

@export var condition_name: String
@export var icon: Texture
@export var condition_type: ConditionType = ConditionType.BUFF

@export_group("Stat Modifiers")
@export var speed_mod: int = 0
@export var precision_mod: int = 0

@export_group("Global Multipliers")
@export var damage_dealt_scalar: float = 0.0
@export var damage_taken_scalar: float = 0.0

@export_group("Triggers & Effects")
@export var is_passive: bool = false
@export var retarget: bool = false
@export var triggers: Array[Trigger]
@export var remove_on_triggers: Array[Trigger.TriggerType]
