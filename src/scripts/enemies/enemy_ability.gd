extends Resource
class_name EnemyAbility

@export var ability_id: StringName
@export var action: Action
@export_range(0, 99, 1) var cooldown_turns := 0
@export_range(0, 99, 1) var initial_cooldown := 0
@export var one_time_use := false
@export var rules: Array[EnemyDecisionRule] = []


func validate(source: String) -> PackedStringArray:
	var label := "%s ability '%s'" % [source, ability_id]
	var errors := PackedStringArray()
	if ability_id.is_empty():
		errors.append("%s ability_id must not be empty." % source)
	if action == null:
		errors.append("%s action must not be null." % label)
	if initial_cooldown < 0 or initial_cooldown > cooldown_turns:
		errors.append("%s initial_cooldown must be between 0 and cooldown_turns." % label)
	if rules.is_empty():
		errors.append("%s rules must not be empty." % label)
	for index in rules.size():
		if rules[index] == null:
			errors.append("%s rule %d is null." % [label, index])
		else:
			errors.append_array(rules[index].validate("%s rule %d" % [label, index]))
			var selector := rules[index].selector
			if action != null and selector != null:
				var uses_candidate_pool := selector.type == EnemyTargetSelector.Type.VALID_HERO_CANDIDATES
				if action.target_type == Action.TargetType.RANDOM_ENEMY and not uses_candidate_pool:
					errors.append("%s RANDOM_ENEMY rules require VALID_HERO_CANDIDATES." % label)
				elif action.target_type != Action.TargetType.RANDOM_ENEMY and uses_candidate_pool:
					errors.append("%s may use VALID_HERO_CANDIDATES only with RANDOM_ENEMY." % label)
	return errors
