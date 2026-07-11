class_name ProgressionPurchaseResult
extends RefCounted

enum Status {
	PURCHASED,
	INVALID_HERO,
	ROLE_LOCKED,
	NODE_NOT_FOUND,
	ALREADY_OWNED,
	PREREQUISITE_LOCKED,
	INSUFFICIENT_XP,
	INVALID_EFFECT,
	REVISION_MISMATCH,
}

var status: Status
var role_id: String
var node_id: String
var xp_paid: int
var content_revision: int


func _init(result_status: Status, result_role_id: String, result_node_id: String, paid: int = 0, revision: int = 0) -> void:
	status = result_status
	role_id = result_role_id
	node_id = result_node_id
	xp_paid = paid
	content_revision = revision
