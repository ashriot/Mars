class_name ProgressionEffect
extends RefCounted

enum Type {
	STAT,
	ACTION,
	PASSIVE,
	SHIFT_ACTION,
}

var _type: Type
var _target: String
var _amount: int

var type: Type:
	get:
		return _type

var target: String:
	get:
		return _target

var amount: int:
	get:
		return _amount


func _init(effect_type: Type, effect_target: String, effect_amount: int) -> void:
	_type = effect_type
	_target = effect_target
	_amount = effect_amount


static func stat(stat_name: String, stat_amount: int) -> ProgressionEffect:
	return ProgressionEffect.new(Type.STAT, stat_name, stat_amount)


static func action(action_path: String, action_amount: int) -> ProgressionEffect:
	return ProgressionEffect.new(Type.ACTION, action_path, action_amount)


static func passive(passive_path: String, passive_amount: int) -> ProgressionEffect:
	return ProgressionEffect.new(Type.PASSIVE, passive_path, passive_amount)


static func shift_action(action_path: String, action_amount: int) -> ProgressionEffect:
	return ProgressionEffect.new(Type.SHIFT_ACTION, action_path, action_amount)
