class_name ProgressionContentError
extends RefCounted

var source_path: String
var node_id: String
var field: String
var reason: String


func _init(error_source_path: String, error_node_id: String, error_field: String, error_reason: String) -> void:
	source_path = error_source_path
	node_id = error_node_id
	field = error_field
	reason = error_reason


func _to_string() -> String:
	var context := source_path
	if not node_id.is_empty():
		context += " [%s]" % node_id
	return "%s %s: %s" % [context, field, reason]
