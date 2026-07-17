class_name DamageContribution
extends RefCounted

enum Stage {
	POTENCY,
	POWER,
	OUTGOING,
	INCOMING,
}

var _source: StringName
var _stage: Stage
var _amount: float

var source: StringName:
	get: return _source
var stage: Stage:
	get: return _stage
var amount: float:
	get: return _amount


func _init(contribution_source: StringName, contribution_stage: Stage, contribution_amount: float) -> void:
	_source = contribution_source
	_stage = contribution_stage
	_amount = contribution_amount
