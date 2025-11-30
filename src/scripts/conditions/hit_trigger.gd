extends Resource
class_name HitTrigger

enum HitCondition {
	ALWAYS,
	IF_TARGET_IS_BREACHED,
	IF_TARGET_HAS_DEBUFF,
	IF_ATTACKER_HAS_BUFF
	# (You can add more here later, like IF_HIT_IS_CRIT)
}
@export var condition: HitCondition = HitCondition.ALWAYS
@export var context: String
@export var effects_to_run: Array[ActionEffect]
