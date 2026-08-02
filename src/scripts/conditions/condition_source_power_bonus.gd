class_name ConditionSourcePowerBonus
extends Condition

@export var power_type: Action.PowerType = Action.PowerType.PSYCHE
@export var power_scalar: float = 1.0


func get_damage_dealt_power_bonus(_attacker: Node, _target: Node) -> float:
	if not is_instance_valid(attacker):
		return 0.0
	return float(attacker.get_power(power_type)) * power_scalar
