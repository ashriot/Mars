extends Resource
class_name EnemyTargetSelector

enum Type {
	SELF,
	ALL_HEROES,
	ALL_ALLIES,
	SEEDED_HERO,
	VALID_HERO_CANDIDATES,
	PREFERRED_CONDITION_HERO,
	HIGHEST_FOCUS_HERO,
	HIGHEST_GUARD_HERO,
	LOWEST_GUARD_HERO,
	HERO_CLOSEST_TO_ACTING,
	LOWEST_HP_PERCENT_ALLY,
	LEAST_GUARD_ALLY,
	ALLY_FURTHEST_FROM_ACTING,
}

@export var type: Type = Type.SEEDED_HERO
@export var condition_name: String = ""
@export var exclude_self := false


func select(enemy: EnemyCombatant, state: EnemyAIRuntimeState, context: EnemyAIContext,
	salt: String) -> Array[BattleCombatant]:
	var heroes := _eligible_heroes(context)
	var allies := _eligible_allies(enemy, context)
	match type:
		Type.SELF:
			return [enemy]
		Type.ALL_HEROES:
			return _as_combatants(heroes)
		Type.ALL_ALLIES:
			return _as_combatants(allies)
		Type.VALID_HERO_CANDIDATES:
			return _as_combatants(heroes)
		Type.PREFERRED_CONDITION_HERO:
			var preferred := heroes.filter(func(hero: HeroCombatant):
				return hero.has_condition(condition_name))
			return _seeded_one(preferred if not preferred.is_empty() else heroes,
				enemy, state, context, salt)
		Type.HIGHEST_FOCUS_HERO:
			return _extreme_one(heroes, func(hero: HeroCombatant): return hero.current_focus,
				true, enemy, state, context, salt)
		Type.HIGHEST_GUARD_HERO:
			return _extreme_one(heroes, func(hero: HeroCombatant): return hero.current_guard,
				true, enemy, state, context, salt)
		Type.LOWEST_GUARD_HERO:
			return _extreme_one(heroes, func(hero: HeroCombatant): return hero.current_guard,
				false, enemy, state, context, salt)
		Type.HERO_CLOSEST_TO_ACTING:
			return _extreme_one(heroes, func(hero: HeroCombatant): return context.ticks_until(hero),
				false, enemy, state, context, salt)
		Type.LOWEST_HP_PERCENT_ALLY:
			return _extreme_one(allies, func(ally: EnemyCombatant):
				return float(ally.current_hp) / maxf(ally.current_stats.max_hp, 1),
				false, enemy, state, context, salt)
		Type.LEAST_GUARD_ALLY:
			return _extreme_one(allies, func(ally: EnemyCombatant): return ally.current_guard,
				false, enemy, state, context, salt)
		Type.ALLY_FURTHEST_FROM_ACTING:
			return _extreme_one(allies, func(ally: EnemyCombatant): return context.ticks_until(ally),
				true, enemy, state, context, salt)
		_:
			return _seeded_one(heroes, enemy, state, context, salt)


func targets_are_legal(enemy: EnemyCombatant, targets: Array[BattleCombatant],
	context: EnemyAIContext) -> bool:
	var heroes := _eligible_heroes(context)
	var allies := _eligible_allies(enemy, context)
	match type:
		Type.SELF:
			return targets == [enemy]
		Type.ALL_HEROES, Type.VALID_HERO_CANDIDATES:
			return _same_actor_set(targets, heroes)
		Type.ALL_ALLIES:
			return _same_actor_set(targets, allies)
		Type.SEEDED_HERO, Type.PREFERRED_CONDITION_HERO, \
			Type.HIGHEST_FOCUS_HERO, Type.HIGHEST_GUARD_HERO, \
			Type.LOWEST_GUARD_HERO, Type.HERO_CLOSEST_TO_ACTING:
			return targets.size() == 1 and targets[0] in heroes
		Type.LOWEST_HP_PERCENT_ALLY, Type.LEAST_GUARD_ALLY, \
			Type.ALLY_FURTHEST_FROM_ACTING:
			return targets.size() == 1 and targets[0] in allies
	return false


func _eligible_heroes(context: EnemyAIContext) -> Array[HeroCombatant]:
	var heroes: Array[HeroCombatant] = context.heroes.filter(func(hero: HeroCombatant):
		return is_instance_valid(hero) and not hero.is_defeated \
			and not hero.is_untargetable()
	)
	if not _is_hostile_selector():
		return heroes
	var taunts: Array[HeroCombatant] = heroes.filter(func(hero: HeroCombatant):
		return hero.is_taunting()
	)
	return taunts if not taunts.is_empty() else heroes


func _eligible_allies(enemy: EnemyCombatant,
	context: EnemyAIContext) -> Array[EnemyCombatant]:
	var allies: Array[EnemyCombatant] = context.enemies.filter(func(ally: EnemyCombatant):
		return is_instance_valid(ally) and not ally.is_defeated \
			and (not exclude_self or ally != enemy)
	)
	return allies


func _is_hostile_selector() -> bool:
	return type in [
		Type.SEEDED_HERO,
		Type.VALID_HERO_CANDIDATES,
		Type.PREFERRED_CONDITION_HERO,
		Type.HIGHEST_FOCUS_HERO,
		Type.HIGHEST_GUARD_HERO,
		Type.LOWEST_GUARD_HERO,
		Type.HERO_CLOSEST_TO_ACTING,
	]


func _same_actor_set(left: Array, right: Array) -> bool:
	return left.size() == right.size() and left.all(func(actor):
		return actor in right
	)


func _as_combatants(values: Array) -> Array[BattleCombatant]:
	var actors: Array[BattleCombatant] = []
	for value in values:
		if value is BattleCombatant:
			actors.append(value)
	return actors


func _seeded_one(values: Array, enemy: EnemyCombatant, state: EnemyAIRuntimeState,
	context: EnemyAIContext, salt: String) -> Array[BattleCombatant]:
	var tied := _as_combatants(values)
	if tied.is_empty():
		return []
	tied.sort_custom(func(left: BattleCombatant, right: BattleCombatant) -> bool:
		return left.battle_priority < right.battle_priority)
	var index := posmod(hash("%d:%d:%d:%s" % [
		context.encounter_seed,
		enemy.battle_priority,
		state.completed_turns,
		salt,
	]), tied.size())
	return [tied[index]]


func _extreme_one(values: Array, value_for: Callable, highest: bool,
	enemy: EnemyCombatant, state: EnemyAIRuntimeState, context: EnemyAIContext,
	salt: String) -> Array[BattleCombatant]:
	var actors := _as_combatants(values)
	if actors.is_empty():
		return []
	var extreme = value_for.call(actors[0])
	var tied: Array[BattleCombatant] = [actors[0]]
	for index in range(1, actors.size()):
		var actor := actors[index]
		var value = value_for.call(actor)
		if (highest and value > extreme) or (not highest and value < extreme):
			extreme = value
			tied = [actor]
		elif value == extreme:
			tied.append(actor)
	return _seeded_one(tied, enemy, state, context, salt)


func validate(source: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if type == Type.PREFERRED_CONDITION_HERO and condition_name.is_empty():
		errors.append("%s preferred-condition selector requires condition_name." % source)
	return errors


func guarantees_legal_target(target_type: Action.TargetType) -> bool:
	match target_type:
		Action.TargetType.ONE_ENEMY:
			return type in [Type.SEEDED_HERO, Type.PREFERRED_CONDITION_HERO,
				Type.HIGHEST_FOCUS_HERO, Type.HIGHEST_GUARD_HERO, Type.LOWEST_GUARD_HERO,
				Type.HERO_CLOSEST_TO_ACTING]
		Action.TargetType.ALL_ENEMIES:
			return type == Type.ALL_HEROES
		Action.TargetType.RANDOM_ENEMY:
			return type == Type.VALID_HERO_CANDIDATES
		Action.TargetType.SELF:
			return type == Type.SELF
		Action.TargetType.ONE_ALLY:
			return type == Type.SELF or (type in [Type.LOWEST_HP_PERCENT_ALLY,
				Type.LEAST_GUARD_ALLY, Type.ALLY_FURTHEST_FROM_ACTING] and not exclude_self)
		Action.TargetType.ALL_ALLIES:
			return type == Type.ALL_ALLIES and not exclude_self
		Action.TargetType.LEAST_GUARD_ALLY:
			return type == Type.LEAST_GUARD_ALLY and not exclude_self
	return false
