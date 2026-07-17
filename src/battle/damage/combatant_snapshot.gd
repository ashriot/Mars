class_name CombatantSnapshot
extends RefCounted

var _current_hp: int
var _current_focus: int
var _current_guard: int
var _is_breached: bool
var _is_defeated: bool
var _condition_names: Array[StringName]

var current_hp: int:
	get: return _current_hp
var current_focus: int:
	get: return _current_focus
var current_guard: int:
	get: return _current_guard
var is_breached: bool:
	get: return _is_breached
var is_defeated: bool:
	get: return _is_defeated
var condition_names: Array[StringName]:
	get: return _condition_names.duplicate()


func _init(
	combatant_current_hp: int,
	combatant_current_focus: int,
	combatant_current_guard: int,
	combatant_is_breached: bool,
	combatant_is_defeated: bool,
	combatant_condition_names: Array[StringName] = [],
) -> void:
	_current_hp = combatant_current_hp
	_current_focus = combatant_current_focus
	_current_guard = combatant_current_guard
	_is_breached = combatant_is_breached
	_is_defeated = combatant_is_defeated
	_condition_names = combatant_condition_names.duplicate()


static func capture(actor: ActorCard) -> CombatantSnapshot:
	var condition_names: Array[StringName] = []
	for condition in actor.active_conditions:
		condition_names.append(StringName(condition.condition_name))
	var current_focus: int = actor.current_focus if actor is HeroCard else 0
	return CombatantSnapshot.new(
		actor.current_hp,
		current_focus,
		actor.current_guard,
		actor.is_breached,
		actor.is_defeated,
		condition_names,
	)
