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


func validate(source: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if type == Type.PREFERRED_CONDITION_HERO and condition_name.is_empty():
		errors.append("%s preferred-condition selector requires condition_name." % source)
	return errors
