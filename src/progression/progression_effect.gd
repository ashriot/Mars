class_name ProgressionEffect
extends RefCounted

enum Type {
	STAT,
	ACTION,
	PASSIVE,
	SHIFT_ACTION,
}

# Underscore-prefixed backing fields are internal implementation details. GDScript
# does not enforce private access; callers use the getter-only public properties.
var _type: Type
var _target: String
var _amount: int
var _is_valid: bool = false
var _validation_error: String = ""

var type: Type:
	get:
		return _type

var target: String:
	get:
		return _target

var amount: int:
	get:
		return _amount

var is_valid: bool:
	get:
		return _is_valid

var validation_error: String:
	get:
		return _validation_error


func _init(effect_type: Type, effect_target: String, effect_amount: int) -> void:
	_type = effect_type
	_target = effect_target
	_amount = effect_amount
	_validate()


func _validate() -> void:
	if _type < Type.STAT or _type > Type.SHIFT_ACTION:
		_validation_error = "Unknown progression effect type."
		return
	if _target.is_empty():
		_validation_error = "Progression effect target cannot be empty."
		return
	match _type:
		Type.STAT:
			if _amount == 0:
				_validation_error = "Stat effects require a nonzero amount."
				return
		Type.ACTION:
			if _amount <= 0:
				_validation_error = "Action effects require a positive slot."
				return
		Type.PASSIVE, Type.SHIFT_ACTION:
			if _amount != 0:
				_validation_error = "Passive and shift-action effects do not accept a slot."
				return
	_is_valid = true


static func stat(stat_name: String, stat_amount: int) -> ProgressionEffect:
	return ProgressionEffect.new(Type.STAT, stat_name, stat_amount)


static func action(action_path: String, action_amount: int) -> ProgressionEffect:
	return ProgressionEffect.new(Type.ACTION, action_path, action_amount)


static func passive(passive_path: String) -> ProgressionEffect:
	return ProgressionEffect.new(Type.PASSIVE, passive_path, 0)


static func shift_action(action_path: String) -> ProgressionEffect:
	return ProgressionEffect.new(Type.SHIFT_ACTION, action_path, 0)
