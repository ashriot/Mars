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
	_load_optional_local_models(room)


func _load_optional_local_models(room: Node) -> void:
	for node: Node in room.find_children("*", "", true, false):
		if node is OptionalLocalModel3D:
			(node as OptionalLocalModel3D).try_load()


func _process(_delta: float) -> void:
	_layout_enemy_huds()


func _layout_enemy_huds() -> void:
	if not is_instance_valid(hud_layer):
		return
	var layer_size := hud_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		layer_size = get_viewport().get_visible_rect().size
	var safe_rect := Rect2(Vector2.ZERO, layer_size).grow(-HUD_SAFE_MARGIN)
	var visible_huds: Array[EnemyWorldHUD] = []
	var reserved_rects: Array[Rect2] = []
	var upper_reservations: Array[float] = []
	for child: Node in hud_layer.get_children():
		if child is not EnemyWorldHUD:
			continue
		var hud := child as EnemyWorldHUD
		hud.set_safe_rect(safe_rect)
		if not hud.visible or not hud.has_valid_projection():
			continue
		var rect := hud.get_desired_compact_rect()
		rect.position.x = clampf(
			rect.position.x, safe_rect.position.x, safe_rect.end.x - rect.size.x,
		)
		var reserved_rect := hud.get_reserved_layout_rect(rect)
		var upper_reservation := rect.position.y - reserved_rect.position.y
		var lower_reservation := reserved_rect.end.y - rect.end.y
		rect.position.y = clampf(
			rect.position.y,
			safe_rect.position.y + upper_reservation,
			safe_rect.end.y - rect.size.y - lower_reservation,
		)
		visible_huds.append(hud)
		reserved_rects.append(hud.get_reserved_layout_rect(rect))
		upper_reservations.append(upper_reservation)
	var resolved_reserved_rects := EnemyHUDLayout.resolve(reserved_rects, safe_rect)
	if resolved_reserved_rects.size() != visible_huds.size():
		return
	for index: int in visible_huds.size():
		var hud := visible_huds[index]
		var reserved_rect := resolved_reserved_rects[index]
		var compact_rect := Rect2(
			Vector2(reserved_rect.position.x, reserved_rect.position.y + upper_reservations[index]),
			hud.get_desired_compact_rect().size,
		)
		hud.apply_resolved_compact_rect(compact_rect)


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
