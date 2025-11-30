extends Resource
class_name PreHitTrigger

enum PreHitCondition {
	ALWAYS,
	IF_TARGET_HAS_CONDITION,
	IF_TARGET_IS_BREACHED,
	IF_TARGET_HAS_ANY_DEBUFF
}
@export var condition: PreHitCondition = PreHitCondition.ALWAYS

@export var string_context: String = ""

@export var effects_to_run: Array[PreHitEffect]
