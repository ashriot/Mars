extends Resource
class_name Trigger

enum TriggerType {
	ON_TURN_START,
	ON_TURN_END,
	ON_BEING_HIT,    # (After damage is calculated)
	ON_TAKING_KINETIC_DAMAGE,
	ON_GAINING_GUARD,
	ON_SHIFTING
}
@export var trigger_type: TriggerType

@export var effects: Array[ActionEffect]
