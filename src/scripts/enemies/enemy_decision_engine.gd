extends RefCounted
class_name EnemyDecisionEngine


static func choose(enemy: EnemyCombatant, abilities: Array[EnemyAbility], state: EnemyAIRuntimeState,
	context: EnemyAIContext) -> EnemyDecision:
	var candidates: Array[Dictionary] = []
	for ability in abilities:
		if ability == null or not state.is_ready(ability):
			continue
		for index in ability.rules.size():
			var rule := ability.rules[index]
			if rule == null or not rule.conditions.all(func(condition: EnemyDecisionCondition):
				return condition != null and condition.matches(enemy, state, context)):
				continue
			var salt := "%s:%d" % [ability.ability_id, index]
			var targets := rule.selector.select(enemy, state, context, salt) if rule.selector else []
			if targets.is_empty():
				continue
			candidates.append({"ability": ability, "rule": rule, "targets": targets, "salt": salt})
	if candidates.is_empty():
		return EnemyDecision.new()
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left.rule.priority != right.rule.priority:
			return left.rule.priority > right.rule.priority
		if left.ability.cooldown_turns != right.ability.cooldown_turns:
			return left.ability.cooldown_turns > right.ability.cooldown_turns
		return _stable_key(enemy, state, context, left.salt) \
			< _stable_key(enemy, state, context, right.salt)
	)
	var winner := candidates[0]
	var decision := EnemyDecision.new()
	decision.ability = winner.ability
	decision.action = winner.ability.action
	decision.rule = winner.rule
	decision.targets.assign(winner.targets)
	decision.reason = winner.rule.reason
	return decision


static func _stable_key(enemy: EnemyCombatant, state: EnemyAIRuntimeState,
	context: EnemyAIContext, salt: String) -> int:
	return hash("%d:%d:%d:%s" % [
		context.encounter_seed,
		enemy.battle_priority,
		state.completed_turns,
		salt,
	])
