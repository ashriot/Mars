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

var _status: Status
var _role_id: String
var _node_id: String
var _xp_paid: int
var _content_revision: int
var _hero: HeroData
var _resulting_xp: int

var status: Status:
	get: return _status
var role_id: String:
	get: return _role_id
var node_id: String:
	get: return _node_id
var xp_paid: int:
	get: return _xp_paid
var content_revision: int:
	get: return _content_revision
var hero: HeroData:
	get: return _hero
var resulting_xp: int:
	get: return _resulting_xp


func _init(result_status: Status, result_role_id: String, result_node_id: String, paid: int = 0, revision: int = 0, result_hero: HeroData = null, hero_xp: int = -1) -> void:
	_status = result_status
	_role_id = result_role_id
	_node_id = result_node_id
	_xp_paid = paid
	_content_revision = revision
	_hero = result_hero
	_resulting_xp = hero_xp
