extends Resource
class_name Trigger

enum TriggerType {
	ON_APPLIED,
	ON_TURN_START,
	ON_TURN_END,
	BEFORE_BEING_ATTACKED,
	ON_BEING_HIT,
	ON_TAKING_KINETIC_DAMAGE,
	ON_TAKING_ENERGY_DAMAGE,
	AFTER_BEING_ATTACKED,
	AFTER_ATTACKING,
	ON_GAINING_GUARD,
	ON_HEALED,
	ON_SHIFT,
	ON_BREACHED
}
@export var trigger_type: TriggerType
@export var effects_to_run: Array[ActionEffect]
