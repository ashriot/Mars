extends Resource
class_name Condition

enum ConditionType { BUFF, DEBUFF }

@export var condition_name: String
@export var icon: Texture
@export_multiline var description: String = ""
@export var condition_type: ConditionType = ConditionType.BUFF
@export var is_passive: bool = false
@export var triggered_by: Action.HeroType = Action.HeroType.ALL

@export_group("Stat Modifiers")
@export var force_damage_type: Action.DamageType = Action.DamageType.NONE
@export var precision_mod: int = 0
@export var incoming_precision_mod: int = 0
@export var speed_scalar: float = 0.0
@export var damage_dealt_scalar: float = 0.0
@export var damage_taken_scalar: float = 0.0
@export var focus_cost_reduction: float = 0.0

@export_group("Triggers & Effects")
@export var update_turn_order: bool
@export var retarget: bool = false
@export var triggers: Array[Trigger]
@export var remove_on_triggers: Array[Trigger.TriggerType]

var id: String = resource_path.get_file().get_basename()
var attacker: ActorCard
