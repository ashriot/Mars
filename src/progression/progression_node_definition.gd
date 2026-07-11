class_name ProgressionNodeDefinition
extends RefCounted

var _id: String
var _parent_id: String
var _rank: int
var _column: int
var _cost: int
var _effect: ProgressionEffect

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
