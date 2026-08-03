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
	var huds: Array[EnemyWorldHUD] = []
	var desired_rects: Array[Rect2] = []
	for child: Node in hud_layer.get_children():
		if child is EnemyWorldHUD:
			var hud := child as EnemyWorldHUD
			hud.set_safe_rect(safe_rect)
			if hud.visible and hud.has_valid_projection():
				huds.append(hud)
				desired_rects.append(hud.get_desired_compact_rect())
	if huds.is_empty():
		return
	var resolved := EnemyHUDLayout.resolve(desired_rects, safe_rect)
	if resolved.size() != huds.size():
		return
	for index in huds.size():
		huds[index].apply_resolved_compact_rect(resolved[index])
	var occupied: Array[Rect2] = resolved.duplicate()
	for index in huds.size():
		var hud := huds[index]
		if not hud.details.visible:
			continue
		var detail_rect := _resolve_details_rect(resolved[index], occupied, safe_rect)
		if detail_rect.size == Vector2.ZERO:
			push_error("BattleWorld3D cannot place enemy HUD details inside the safe area.")
			continue
		hud.apply_details_rect(detail_rect)
		occupied.append(detail_rect)


func _resolve_details_rect(
	owner_compact: Rect2,
	occupied: Array[Rect2],
	safe_rect: Rect2,
) -> Rect2:
	var x_positions: Array[float] = [
		owner_compact.position.x,
		safe_rect.position.x,
		safe_rect.end.x - EnemyWorldHUD.DETAILS_SIZE.x,
	]
	var y_positions: Array[float] = [
		owner_compact.position.y - EnemyWorldHUD.DETAILS_GAP \
			- EnemyWorldHUD.DETAILS_SIZE.y,
		owner_compact.end.y + EnemyWorldHUD.DETAILS_GAP,
		safe_rect.position.y,
		safe_rect.end.y - EnemyWorldHUD.DETAILS_SIZE.y,
	]
	for obstacle: Rect2 in occupied:
		_append_unique_float(x_positions, obstacle.position.x)
		_append_unique_float(
			x_positions,
			obstacle.position.x - EnemyWorldHUD.DETAILS_GAP \
				- EnemyWorldHUD.DETAILS_SIZE.x,
		)
		_append_unique_float(
			x_positions, obstacle.end.x + EnemyWorldHUD.DETAILS_GAP,
		)
		_append_unique_float(y_positions, obstacle.position.y)
		_append_unique_float(
			y_positions,
			obstacle.position.y - EnemyWorldHUD.DETAILS_GAP \
				- EnemyWorldHUD.DETAILS_SIZE.y,
		)
		_append_unique_float(
			y_positions, obstacle.end.y + EnemyWorldHUD.DETAILS_GAP,
		)

	var candidates: Array[Rect2] = []
	for x: float in x_positions:
		for y: float in y_positions:
			var candidate := Rect2(
				Vector2(
					clampf(
						x, safe_rect.position.x,
						safe_rect.end.x - EnemyWorldHUD.DETAILS_SIZE.x,
					),
					clampf(
						y, safe_rect.position.y,
						safe_rect.end.y - EnemyWorldHUD.DETAILS_SIZE.y,
					),
				),
				EnemyWorldHUD.DETAILS_SIZE,
			)
			if not candidates.has(candidate):
				candidates.append(candidate)
	var owner_center := owner_compact.get_center()
	candidates.sort_custom(func(left: Rect2, right: Rect2) -> bool:
		var left_distance := left.get_center().distance_squared_to(owner_center)
		var right_distance := right.get_center().distance_squared_to(owner_center)
		if left_distance != right_distance:
			return left_distance < right_distance
		if left.position.y != right.position.y:
			return left.position.y < right.position.y
		return left.position.x < right.position.x
	)
	for candidate: Rect2 in candidates:
		if _details_rect_is_clear(candidate, occupied, safe_rect):
			return candidate
	return Rect2()


func _details_rect_is_clear(
	candidate: Rect2,
	occupied: Array[Rect2],
	safe_rect: Rect2,
) -> bool:
	if not safe_rect.encloses(candidate):
		return false
	for obstacle: Rect2 in occupied:
		if candidate.grow(EnemyWorldHUD.DETAILS_GAP * 0.5).intersects(
			obstacle.grow(EnemyWorldHUD.DETAILS_GAP * 0.5),
		):
			return false
	return true


func _append_unique_float(values: Array[float], value: float) -> void:
	if not values.has(value):
		values.append(value)


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
