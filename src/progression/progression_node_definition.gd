class_name ProgressionNodeDefinition
extends RefCounted

enum NodeKind { PROGRESSION, ROLE_ANCHOR }

var _kind: NodeKind
var _id: String
var _parent_id: String
var _rank: int
var _column: int
var _cost: int
var _effect: ProgressionEffect
var _starting_owned: bool
var _is_valid: bool = false
var _validation_error: String = ""

var kind: NodeKind:
	get: return _kind
var id: String:
	get: return _id
var parent_id: String:
	get: return _parent_id
var rank: int:
	get: return _rank
var column: int:
	get: return _column
var cost: int:
	get: return _cost
var effect: ProgressionEffect:
	get: return _effect
var starting_owned: bool:
	get: return _starting_owned
var is_structural: bool:
	get: return _kind == NodeKind.ROLE_ANCHOR
var is_valid: bool:
	get: return _is_valid
var validation_error: String:
	get: return _validation_error


func _init(
	first: Variant,
	second: Variant,
	third: Variant,
	fourth: Variant,
	fifth: Variant,
	sixth: Variant,
	seventh: Variant = null,
	eighth: Variant = false,
) -> void:
	# The six-argument form remains accepted while callers migrate to factories.
	if first is String:
		_kind = NodeKind.PROGRESSION
		_id = first
		_parent_id = second
		_rank = third
		_column = fourth
		_cost = fifth
		_effect = sixth
		_starting_owned = false
	else:
		_kind = first
		_id = second
		_parent_id = third
		_rank = fourth
		_column = fifth
		_cost = sixth
		_effect = seventh
		_starting_owned = eighth
	_validate()


static func role_anchor(node_id: String, node_rank: int, node_column: int) -> ProgressionNodeDefinition:
	return ProgressionNodeDefinition.new(NodeKind.ROLE_ANCHOR, node_id, "", node_rank, node_column, 0, null, false)


static func progression(
	node_id: String,
	node_parent_id: String,
	node_rank: int,
	node_column: int,
	node_cost: int,
	node_effect: ProgressionEffect,
	node_starting_owned: bool = false,
) -> ProgressionNodeDefinition:
	return ProgressionNodeDefinition.new(
		NodeKind.PROGRESSION, node_id, node_parent_id, node_rank, node_column,
		node_cost, node_effect, node_starting_owned,
	)


func _validate() -> void:
	if _kind == NodeKind.ROLE_ANCHOR:
		if not _parent_id.is_empty() or _rank != 1 or _column != 0:
			_validation_error = "Role anchors must be parentless at rank 1, column 0."
		elif _cost != 0 or _effect != null or _starting_owned:
			_validation_error = "Role anchors cannot have cost, effects, or starting ownership."
		else:
			_is_valid = true
		return
	if _effect == null:
		_validation_error = "Progression nodes require an effect."
	elif not _effect.is_valid:
		_validation_error = "Progression nodes require a valid effect: %s" % _effect.validation_error
	elif _starting_owned and _cost != 0:
		_validation_error = "Starting-owned progression nodes must have zero cost."
	elif not _starting_owned and _cost <= 0:
		_validation_error = "Paid progression nodes require a positive cost."
	else:
		_is_valid = true
