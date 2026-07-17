class_name EffectPresentation
extends RefCounted

var _clause_template: String
var _bindings: Dictionary
var _details: Array[String]

var clause_template: String:
	get: return _clause_template
var bindings: Dictionary:
	get: return _bindings.duplicate(true)
var details: Array[String]:
	get: return _details.duplicate()


func _init(
	presentation_clause_template: String,
	presentation_bindings: Dictionary = {},
	presentation_details: Array[String] = [],
) -> void:
	_clause_template = presentation_clause_template
	_bindings = presentation_bindings.duplicate(true)
	_details = presentation_details.duplicate()


func render() -> String:
	var rendered := _clause_template
	var render_bindings := _bindings.duplicate(true)
	for binding_name in render_bindings:
		rendered = rendered.replace(
			"{%s}" % str(binding_name),
			str(render_bindings[binding_name]),
		)
	return rendered
