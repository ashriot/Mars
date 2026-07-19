extends RefCounted
class_name EnemyKitValidator


static func validate(enemy: EnemyData, source: String = "") -> PackedStringArray:
	var label := source if not source.is_empty() else "enemy '%s'" % (enemy.enemy_id if enemy else "<null>")
	var errors := PackedStringArray()
	if enemy == null:
		errors.append("%s is null." % label)
		return errors
	var ids := {}
	var has_fallback := false
	for ability in enemy.abilities:
		if ability == null:
			errors.append("%s contains a null ability." % label)
			continue
		errors.append_array(ability.validate(label))
		if ids.has(ability.ability_id):
			errors.append("%s has Duplicate ability ID '%s'." % [label, ability.ability_id])
		ids[ability.ability_id] = true
		if ability.cooldown_turns == 0 and not ability.one_time_use \
		and ability.action != null and ability.rules.any(func(rule: EnemyDecisionRule):
			return rule != null and rule.is_unconditional() and rule.selector != null \
				and rule.selector.guarantees_legal_target(ability.action.target_type)
		):
			has_fallback = true
	if not has_fallback:
		errors.append("%s requires an unconditional free action with a guaranteed legal target." % label)
	return errors
