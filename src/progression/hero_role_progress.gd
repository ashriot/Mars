class_name HeroRoleProgress
extends RefCounted

var content_revision: int
var owned_node_ids: Array[String]
var xp_paid_by_node: Dictionary[String, int]


func _init(revision: int = 0, owned_ids: Array = [], paid_by_node: Dictionary = {}) -> void:
	content_revision = revision
	for node_id in owned_ids:
		owned_node_ids.append(str(node_id))
	for node_id in paid_by_node:
		xp_paid_by_node[str(node_id)] = int(paid_by_node[node_id])


func to_save_data() -> Dictionary:
	return {
		"content_revision": content_revision,
		"owned_node_ids": owned_node_ids.duplicate(),
		"xp_paid_by_node": xp_paid_by_node.duplicate(),
	}


static func from_save_data(data: Variant) -> HeroRoleProgress:
	if not data is Dictionary:
		return null
	if not _is_positive_integral_number(data.get("content_revision")):
		return null
	if not data.get("owned_node_ids") is Array or not data.get("xp_paid_by_node") is Dictionary:
		return null
	var owned: Array[String] = []
	for node_id in data.owned_node_ids:
		if not node_id is String or node_id.is_empty() or node_id in owned:
			return null
		owned.append(node_id)
	var paid: Dictionary[String, int] = {}
	for node_id in data.xp_paid_by_node:
		var amount: Variant = data.xp_paid_by_node[node_id]
		if not node_id is String or not node_id in owned or not _is_non_negative_integral_number(amount):
			return null
		paid[node_id] = int(amount)
	if paid.size() != owned.size():
		return null
	return HeroRoleProgress.new(int(data.content_revision), owned, paid)


static func _is_positive_integral_number(value: Variant) -> bool:
	if value is int:
		return value > 0
	return value is float and value > 0.0 and value == floor(value)


static func _is_non_negative_integral_number(value: Variant) -> bool:
	if value is int:
		return value >= 0
	return value is float and value >= 0.0 and value == floor(value)
