extends Resource
class_name Trigger

enum TriggerType {
	ON_APPLIED,
	ON_TURN_START,
	ON_TURN_END,
	ON_SPENDING_FOCUS,
	BEFORE_BEING_ATTACKED,
	ON_BEING_HIT,
	ON_TAKING_KINETIC_DAMAGE,
	ON_TAKING_ENERGY_DAMAGE,
	AFTER_BEING_ATTACKED,
	AFTER_ATTACKING,
	ON_GAINING_GUARD,
	ON_HEALED,
	ON_SHIFT,
	ON_BREACHED,
	ON_REMOVED,
	BEFORE_BUFF_RECEIVED,
	BEFORE_DEBUFF_RECEIVED
}
@export var trigger_type: TriggerType
@export var effects_to_run: Array[ActionEffect]

var is_attack: bool :
	get:
		for effect in effects_to_run:
			if effect is Effect_Damage:
				return true
		return false
