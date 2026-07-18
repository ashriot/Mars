class_name DamageScalingBasePerResource
extends DamageScalingRule

enum ResourceType {
	FOCUS,
	GUARD,
}

enum ResourceOwner {
	ATTACKER,
	TARGET,
}

@export var resource: ResourceType = ResourceType.FOCUS
@export var resource_owner: ResourceOwner = ResourceOwner.ATTACKER
@export var base_scalar_per_point: float = 0.0


func resolve(base_potency: float, context: DamageContext) -> DamageContribution:
	var amount := base_potency * base_scalar_per_point * _resource_value(context)
	return DamageContribution.new(_source(), DamageContribution.Stage.POTENCY, amount)


func _resource_value(context: DamageContext) -> int:
	var combatant := _combatant(context)
	if combatant == null:
		return 0
	match resource:
		ResourceType.FOCUS:
			return combatant.current_focus
		ResourceType.GUARD:
			return combatant.current_guard
	return 0


func _combatant(context: DamageContext) -> CombatantSnapshot:
	return context.target if resource_owner == ResourceOwner.TARGET else context.attacker


func _source() -> StringName:
	if resource_owner == ResourceOwner.TARGET:
		return &"target_focus" if resource == ResourceType.FOCUS else &"target_guard"
	return &"remaining_focus" if resource == ResourceType.FOCUS else &"current_guard"
