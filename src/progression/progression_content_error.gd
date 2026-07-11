class_name ProgressionContentError
extends RefCounted

var _source_path: String
var _node_id: String
var _field: String
var _reason: String

var source_path: String:
	get:
		return _source_path

var node_id: String:
	get:
		return _node_id

var field: String:
	get:
		return _field

var reason: String:
	get:
		return _reason


func _init(error_source_path: String, error_node_id: String, error_field: String, error_reason: String) -> void:
	_source_path = error_source_path
	_node_id = error_node_id
	_field = error_field
	_reason = error_reason


func _to_string() -> String:
	var context := source_path
	if not node_id.is_empty():
		context += " [%s]" % node_id
	return "%s %s: %s" % [context, field, reason]
