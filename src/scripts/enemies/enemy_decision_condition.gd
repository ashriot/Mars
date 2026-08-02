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


func matches(enemy: EnemyCombatant, state: EnemyAIRuntimeState, context: EnemyAIContext) -> bool:
	match type:
		Type.ALWAYS:
			return true
		Type.FIRST_TURN:
			return state.completed_turns == 0
		Type.SELF_HP_AT_MOST:
			return _hp_percent(enemy) <= threshold
		Type.ANY_ALLY_HP_AT_MOST:
			return context.enemies.any(func(ally: EnemyCombatant):
				return _hp_percent(ally) <= threshold)
		Type.ANY_HERO_FOCUS_AT_LEAST:
			return context.heroes.any(func(hero: HeroCombatant):
				return hero.current_focus >= threshold)
		Type.ANY_HERO_GUARD_AT_LEAST:
			return context.heroes.any(func(hero: HeroCombatant):
				return hero.current_guard >= threshold)
		Type.ANY_HERO_GUARD_AT_MOST:
			return context.heroes.any(func(hero: HeroCombatant):
				return hero.current_guard <= threshold)
		Type.ANY_HERO_BREACHED:
			return context.heroes.any(func(hero: HeroCombatant): return hero.is_breached)
		Type.SELF_MISSING_GUARD:
			return enemy.current_guard <= 0
		Type.ANY_ALLY_MISSING_GUARD:
			return context.enemies.any(func(ally: EnemyCombatant):
				return ally.current_guard <= 0)
		Type.HAS_NAMED_CONDITION:
			return _subjects(enemy, context).any(func(actor: BattleCombatant):
				return actor.has_condition(condition_name))
		Type.LACKS_NAMED_CONDITION:
			return _subjects(enemy, context).any(func(actor: BattleCombatant):
				return not actor.has_condition(condition_name))
		Type.LIVING_HERO_COUNT_AT_LEAST:
			return context.heroes.size() >= count
		Type.LIVING_ALLY_COUNT_AT_LEAST:
			return context.enemies.size() >= count
		Type.HERO_TURN_WITHIN:
			return context.heroes.any(func(hero: HeroCombatant):
				return context.ticks_until(hero) <= int(threshold))
	return false


func _subjects(enemy: EnemyCombatant, context: EnemyAIContext) -> Array[BattleCombatant]:
	match subject:
		Subject.SELF:
			return _as_combatants([enemy])
		Subject.ANY_ALLY:
			return _as_combatants(context.enemies)
		Subject.ANY_HERO:
			return _as_combatants(context.heroes)
	return []


func _hp_percent(actor: BattleCombatant) -> float:
	return float(actor.current_hp) / maxf(actor.current_stats.max_hp, 1.0)


func _as_combatants(values: Array) -> Array[BattleCombatant]:
	var actors: Array[BattleCombatant] = []
	for value in values:
		if value is BattleCombatant:
			actors.append(value)
	return actors


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
