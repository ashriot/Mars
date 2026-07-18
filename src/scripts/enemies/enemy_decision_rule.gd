extends Resource
class_name EnemyDecisionRule

@export var priority: int = 0
@export var conditions: Array[EnemyDecisionCondition] = []
@export var selector: EnemyTargetSelector
@export var reason: String = ""


func is_unconditional() -> bool:
	return conditions.is_empty() or conditions.all(func(value: EnemyDecisionCondition):
		return value != null and value.type == EnemyDecisionCondition.Type.ALWAYS
	)


func validate(source: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if selector == null:
		errors.append("%s rule requires a target selector." % source)
	else:
		errors.append_array(selector.validate(source))
	for index in conditions.size():
		if conditions[index] == null:
			errors.append("%s condition %d is null." % [source, index])
		else:
			errors.append_array(conditions[index].validate("%s condition %d" % [source, index]))
	return errors
