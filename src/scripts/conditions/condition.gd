extends Resource
class_name Condition

enum ConditionType { BUFF, DEBUFF }

@export var condition_name: String
@export var icon: Texture
@export_multiline var description: String = ""
@export var condition_type: ConditionType = ConditionType.BUFF
@export var is_passive: bool = false
@export var is_untargetable: bool = false
@export var is_taunting: bool = false
@export var triggered_by: Action.HeroType = Action.HeroType.ALL

@export_group("Stat Modifiers")
@export var force_damage_type: Action.DamageType = Action.DamageType.NONE
@export var aim_mod: int = 0
@export var incoming_aim_mod: int = 0
@export var speed_scalar: float = 0.0
@export var damage_dealt_scalar: float = 0.0
@export var damage_taken_scalar: float = 0.0
@export var focus_cost_reduction: float = 0.0
@export_range(0.01, 4.0, 0.01) var action_ct_multiplier: float = 1.0

@export_group("Resource Modifiers")
@export var refund_focus_cost_on_spend: bool = false

@export_group("Triggers & Effects")
@export var update_turn_order: bool
@export var triggers: Array[Trigger]
@export var remove_on_triggers: Array[Trigger.TriggerType]

var id: String = resource_path.get_file().get_basename()
var attacker: Node

func get_damage_dealt_power_bonus(_attacker: Node, _target: Node) -> float:
	return 0.0


func get_damage_dealt_modifier(_attacker: Node, _target: Node) -> float:
	return damage_dealt_scalar


func get_damage_taken_modifier(_attacker: Node, _target: Node) -> float:
	return damage_taken_scalar
