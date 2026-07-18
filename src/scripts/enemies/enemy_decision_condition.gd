extends Resource
class_name EnemyDecisionCondition

enum Type {
	ALWAYS,
	FIRST_TURN,
	SELF_HP_AT_MOST,
	ANY_ALLY_HP_AT_MOST,
	ANY_HERO_FOCUS_AT_LEAST,
	ANY_HERO_GUARD_AT_LEAST,
	ANY_HERO_GUARD_AT_MOST,
	ANY_HERO_BREACHED,
	SELF_MISSING_GUARD,
	ANY_ALLY_MISSING_GUARD,
	HAS_NAMED_CONDITION,
	LACKS_NAMED_CONDITION,
	LIVING_HERO_COUNT_AT_LEAST,
	LIVING_ALLY_COUNT_AT_LEAST,
	HERO_TURN_WITHIN,
}
enum Subject { SELF, ANY_ALLY, ANY_HERO }

@export var type: Type = Type.ALWAYS
@export var subject: Subject = Subject.SELF
@export var threshold: float = 0.0
@export var count: int = 1
@export var condition_name: String = ""


func validate(source: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if type in [Type.SELF_HP_AT_MOST, Type.ANY_ALLY_HP_AT_MOST] \
	and (threshold < 0.0 or threshold > 1.0):
		errors.append("%s condition HP threshold must be between 0 and 1." % source)
	if type in [Type.ANY_HERO_FOCUS_AT_LEAST, Type.ANY_HERO_GUARD_AT_LEAST,
		Type.ANY_HERO_GUARD_AT_MOST, Type.HERO_TURN_WITHIN] and threshold < 0.0:
		errors.append("%s condition threshold must be non-negative." % source)
	if type in [Type.LIVING_HERO_COUNT_AT_LEAST, Type.LIVING_ALLY_COUNT_AT_LEAST] and count < 1:
		errors.append("%s condition count must be at least 1." % source)
	if type in [Type.HAS_NAMED_CONDITION, Type.LACKS_NAMED_CONDITION] and condition_name.is_empty():
		errors.append("%s named-condition predicate requires condition_name." % source)
	return errors
