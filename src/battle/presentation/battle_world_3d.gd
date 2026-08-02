extends Node3D
class_name BattleWorld3D

@onready var enemy_views: Node3D = %EnemyViews
@onready var camera: Camera3D = %BattleCamera
@onready var hud_layer: Control = %EnemyHUDLayer


func _ready() -> void:
	var room := get_node_or_null("IndustrialRoom3D")
	if room == null:
		return
	for child: Node in room.get_children():
		if child is OptionalLocalModel3D:
			(child as OptionalLocalModel3D).try_load()


func place_ordinary_view(
	view_root: Node3D,
	index: int,
	total: int,
	layout: BattleFormationLayout.Layout,
) -> bool:
	if not is_instance_valid(view_root) or total < 1 or total > 5 or index < 0 or index >= total:
		return false
	var transforms := BattleFormationLayout.ordinary_transforms(total, layout)
	if index >= transforms.size():
		return false
	_adopt_view(view_root)
	view_root.transform = transforms[index]
	return true


func place_boss_view(view_root: Node3D, ally_index := -1) -> bool:
	if not is_instance_valid(view_root) or ally_index < -1 or ally_index > 1:
		return false
	var layout := BattleFormationLayout.boss_transforms(ally_index + 1)
	var key := &"boss"
	if ally_index == 0:
		key = &"left_ally"
	elif ally_index == 1:
		key = &"right_ally"
	_adopt_view(view_root)
	view_root.transform = layout[key]
	return true


func _adopt_view(view_root: Node3D) -> void:
	if view_root.get_parent() == enemy_views:
		return
	if view_root.get_parent() == null:
		enemy_views.add_child(view_root)
	else:
		view_root.reparent(enemy_views, false)
