class_name ProgressionNodeDefinition
extends RefCounted

# Internal backing fields; supported callers use the getter-only properties.
var _id: String
var _parent_id: String
var _rank: int
var _column: int
var _cost: int
var _effect: ProgressionEffect
var _is_valid: bool = false
var _validation_error: String = ""

var id: String:
	get:
		return _id

var parent_id: String:
	get:
		return _parent_id

var rank: int:
	get:
		return _rank

var column: int:
	get:
		return _column

var cost: int:
	get:
		return _cost

var effect: ProgressionEffect:
	get:
		return _effect

var is_valid: bool:
	get:
		return _is_valid

var validation_error: String:
	get:
		return _validation_error


func _init(
	node_id: String,
	node_parent_id: String,
	node_rank: int,
	node_column: int,
	node_cost: int,
	node_effect: ProgressionEffect,
) -> void:
	_id = node_id
	_parent_id = node_parent_id
	_rank = node_rank
	_column = node_column
	_cost = node_cost
	_effect = node_effect
	if _effect == null:
		_validation_error = "Progression nodes require an effect."
	elif not _effect.is_valid:
		_validation_error = "Progression nodes require a valid effect: %s" % _effect.validation_error
	else:
		_is_valid = true
