extends RefCounted
class_name EnemyAIRuntimeState

var completed_turns := 0
var _remaining: Dictionary[StringName, int] = {}
var _used_once: Dictionary[StringName, bool] = {}
var _abilities: Dictionary[StringName, EnemyAbility] = {}


func initialize(abilities: Array[EnemyAbility]) -> void:
	completed_turns = 0
	_remaining.clear()
	_used_once.clear()
	_abilities.clear()
	for ability in abilities:
		if ability == null:
			continue
		_abilities[ability.ability_id] = ability
		_remaining[ability.ability_id] = ability.initial_cooldown


func remaining(ability_id: StringName) -> int:
	return int(_remaining.get(ability_id, 0))


func has_been_used(ability_id: StringName) -> bool:
	return bool(_used_once.get(ability_id, false))


func is_ready(ability: EnemyAbility) -> bool:
	return ability != null and remaining(ability.ability_id) == 0 \
		and not (ability.one_time_use and has_been_used(ability.ability_id))


func complete_turn(used_ability_id: StringName = &"") -> void:
	for ability_id in _remaining.keys():
		_remaining[ability_id] = maxi(0, int(_remaining[ability_id]) - 1)
	if not used_ability_id.is_empty() and _abilities.has(used_ability_id):
		var ability: EnemyAbility = _abilities[used_ability_id]
		_remaining[used_ability_id] = ability.cooldown_turns
		if ability.one_time_use:
			_used_once[used_ability_id] = true
	completed_turns += 1
