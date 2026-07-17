class_name DamageScalingFlatPerResource
extends DamageScalingRule

enum ResourceType {
	FOCUS,
	GUARD,
}

@export var resource: ResourceType = ResourceType.FOCUS
@export var potency_per_point: float = 0.0


func resolve(_base_potency: float, context: DamageContext) -> DamageContribution:
	var amount := potency_per_point * _resource_value(context)
	return DamageContribution.new(_source(), DamageContribution.Stage.POTENCY, amount)


func _resource_value(context: DamageContext) -> int:
	match resource:
		ResourceType.FOCUS:
			return context.attacker.current_focus
		ResourceType.GUARD:
			return context.attacker.current_guard
	return 0


func _source() -> StringName:
	return &"remaining_focus" if resource == ResourceType.FOCUS else &"current_guard"
