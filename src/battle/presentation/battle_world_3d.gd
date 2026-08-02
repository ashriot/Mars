extends Node3D
class_name BattleWorld3D

const HUD_SAFE_MARGIN := 24.0

@onready var enemy_views: Node3D = %EnemyViews
@onready var camera_rig: BattleCameraRig = %CameraRig
@onready var camera: Camera3D = %BattleCamera
@onready var hud_layer: Control = %EnemyHUDLayer
@onready var projectile_layer: BattleProjectileLayer = %BattleProjectileLayer


func _ready() -> void:
	process_priority = 100
	var room := get_node_or_null("IndustrialRoom3D")
	if room == null:
		return
	for child: Node in room.get_children():
		if child is OptionalLocalModel3D:
			(child as OptionalLocalModel3D).try_load()


func _process(_delta: float) -> void:
	_layout_enemy_huds()


func _layout_enemy_huds() -> void:
	if not is_instance_valid(hud_layer):
		return
	var layer_size := hud_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		layer_size = get_viewport().get_visible_rect().size
	var safe_rect := Rect2(Vector2.ZERO, layer_size).grow(-HUD_SAFE_MARGIN)
	var huds: Array[EnemyWorldHUD] = []
	var desired_rects: Array[Rect2] = []
	for child: Node in hud_layer.get_children():
		if child is EnemyWorldHUD:
			var hud := child as EnemyWorldHUD
			hud.set_safe_rect(safe_rect)
			if hud.visible and hud.has_valid_projection():
				huds.append(hud)
				desired_rects.append(hud.get_desired_layout_rect(safe_rect))
	if huds.is_empty():
		return
	var resolved := EnemyHUDLayout.resolve(desired_rects, safe_rect)
	if resolved.size() != huds.size():
		return
	for index in huds.size():
		huds[index].apply_resolved_layout_rect(resolved[index])


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
