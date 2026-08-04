extends GutTest

const DRONE_SCENE := preload(
	"res://src/battle/presentation/enemy_drone_presentation.tscn",
)
const WORLD_SCENE := preload("res://src/battle/presentation/battle_world_3d.tscn")
const CANVAS_SIZES: Array[Vector2i] = [
	Vector2i(1280, 800),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
]
const SAFE_MARGIN := 24.0
const COMPACT_WIDTH := 220.0
const DETAILS_GAP := 4.0
const CAMERA_YAW_DEGREES: Array[float] = [-3.0, 0.0, 3.0]


func test_w_projects_five_stable_readable_hud_columns_across_camera_yaw() -> void:
	for canvas_size: Vector2i in CANVAS_SIZES:
		await _assert_projected_formation(
			BattleFormationLayout.Layout.W,
			canvas_size,
			[0, 1, 2],
			[3, 4],
		)


func test_m_projects_five_stable_readable_hud_columns_across_camera_yaw() -> void:
	for canvas_size: Vector2i in CANVAS_SIZES:
		await _assert_projected_formation(
			BattleFormationLayout.Layout.M,
			canvas_size,
			[0, 1],
			[2, 3, 4],
		)


func _assert_projected_formation(
	layout: BattleFormationLayout.Layout,
	canvas_size: Vector2i,
	back_indices: Array,
	front_indices: Array,
) -> void:
	var viewport := SubViewport.new()
	viewport.size = canvas_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var world := WORLD_SCENE.instantiate() as BattleWorld3D
	viewport.add_child(world)
	await get_tree().process_frame

	var presentations: Array[EnemyDronePresentation] = []
	for index: int in 5:
		var view_root := DRONE_SCENE.instantiate() as Node3D
		assert_true(world.place_ordinary_view(view_root, index, 5, layout))
		var presentation := view_root.get_node(
			"CombatantPresentation",
		) as EnemyDronePresentation
		assert_true(presentation.setup_view(_enemy(index)))
		presentations.append(presentation)

	await get_tree().process_frame
	for yaw_degrees: float in CAMERA_YAW_DEGREES:
		world.camera_rig.rotation.y = deg_to_rad(yaw_degrees)
		_assert_projection_at_yaw(
			world,
			presentations,
			layout,
			canvas_size,
			back_indices,
			front_indices,
			yaw_degrees,
		)


func _assert_projection_at_yaw(
	world: BattleWorld3D,
	presentations: Array[EnemyDronePresentation],
	layout: BattleFormationLayout.Layout,
	canvas_size: Vector2i,
	back_indices: Array,
	front_indices: Array,
	yaw_degrees: float,
) -> void:
	for presentation: EnemyDronePresentation in presentations:
		presentation._process(0.0)
	world._layout_enemy_huds()

	var compact_rects: Array[Rect2] = []
	var reserved_rects: Array[Rect2] = []
	var model_rects: Array[Rect2] = []
	var safe_rect := Rect2(
		Vector2(SAFE_MARGIN, SAFE_MARGIN),
		Vector2(canvas_size) - Vector2.ONE * SAFE_MARGIN * 2.0,
	)
	for index: int in presentations.size():
		var presentation := presentations[index]
		var compact_rect := presentation.hud.compact_stack.get_global_rect()
		var model_rect := _projected_model_rect(world.camera, presentation)
		compact_rects.append(compact_rect)
		reserved_rects.append(presentation.hud.get_reserved_layout_rect(compact_rect))
		model_rects.append(model_rect)
		assert_true(presentation.is_target_visible())
		assert_eq(
			compact_rect.size.x,
			COMPACT_WIDTH,
			"layout %s canvas %s yaw %s HUD %d keeps the readable width" % [
				layout, canvas_size, yaw_degrees, index,
			],
		)
		assert_eq(presentation.hud.hp_region.size, Vector2(220.0, 32.0))
		assert_eq(presentation.hud.get_node("%HPValue").size, Vector2(220.0, 32.0))
		assert_true(safe_rect.encloses(presentation.hud.get_reserved_layout_rect(compact_rect)))
		assert_true(
			safe_rect.encloses(compact_rect),
			"layout %s canvas %s yaw %s HUD %d stays inside the safe rect: %s" % [
				layout, canvas_size, yaw_degrees, index, compact_rect,
			],
		)
		assert_true(
			presentation.hud.get_target_rect().encloses(model_rect),
			"layout %s canvas %s yaw %s HUD %d target encloses its complete projected model" % [
				layout, canvas_size, yaw_degrees, index,
			],
		)

	_assert_rectangles_do_not_intersect(
		reserved_rects, layout, canvas_size, yaw_degrees,
	)
	for front_index: int in front_indices:
		for back_index: int in back_indices:
			for axis: int in [Vector2.AXIS_X, Vector2.AXIS_Y]:
				assert_gt(
					model_rects[front_index].size[axis],
					model_rects[back_index].size[axis],
					"layout %s canvas %s yaw %s front model %d projects larger on axis %d than back model %d" % [
						layout, canvas_size, yaw_degrees, front_index, axis, back_index,
					],
				)

	for index: int in presentations.size():
		var presentation := presentations[index]
		var original_rect := compact_rects[index]
		presentation.set_inspection_focused(true)
		var detail_rect := presentation.hud.details.get_global_rect()
		assert_eq(detail_rect.position.x, original_rect.position.x)
		assert_eq(
			detail_rect.end.y,
			original_rect.position.y - DETAILS_GAP,
			"layout %s canvas %s yaw %s detail %d keeps its fixed vertical offset" % [
				layout, canvas_size, yaw_degrees, index,
			],
		)
		assert_true(safe_rect.encloses(detail_rect))
		for other_index: int in presentations.size():
			if other_index == index:
				continue
			assert_false(
				detail_rect.intersects(compact_rects[other_index]),
				"layout %s canvas %s yaw %s detail %d avoids compact HUD %d: %s / %s" % [
					layout, canvas_size, yaw_degrees, index, other_index,
					detail_rect, compact_rects[other_index],
				],
			)
		presentation.set_inspection_focused(false)

		for state: CombatantPresentation.TargetState in [
			CombatantPresentation.TargetState.AVAILABLE,
			CombatantPresentation.TargetState.SELECTED,
			CombatantPresentation.TargetState.NORMAL,
		]:
			presentation.set_target_presentation(state)
			assert_eq(
				presentation.hud.compact_stack.get_global_rect(),
				original_rect,
				"layout %s canvas %s yaw %s state %s does not move compact HUD %d" % [
					layout, canvas_size, yaw_degrees, state, index,
				],
			)


func _assert_rectangles_do_not_intersect(
	rectangles: Array[Rect2],
	layout: BattleFormationLayout.Layout,
	canvas_size: Vector2i,
	yaw_degrees: float,
) -> void:
	for first_index: int in rectangles.size():
		for second_index: int in range(first_index + 1, rectangles.size()):
			assert_false(
				rectangles[first_index].intersects(rectangles[second_index]),
				"layout %s canvas %s yaw %s compact HUDs %d and %d do not intersect: %s / %s" % [
					layout,
					canvas_size,
					yaw_degrees,
					first_index,
					second_index,
					rectangles[first_index],
					rectangles[second_index],
				],
			)


func _projected_model_rect(
	camera: Camera3D,
	presentation: EnemyDronePresentation,
) -> Rect2:
	var points: Array[Vector2] = []
	for anchor: Marker3D in [
		presentation.bounds_left_anchor,
		presentation.bounds_right_anchor,
		presentation.bounds_top_anchor,
		presentation.bounds_bottom_anchor,
	]:
		points.append(camera.unproject_position(anchor.global_position))
	var minimum := points[0]
	var maximum := points[0]
	for point: Vector2 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _enemy(index: int) -> EnemyCombatant:
	var stats := ActorStats.new()
	stats.actor_name = "Formation Drone %d" % index
	stats.max_hp = 100
	stats.kinetic_defense = 20
	stats.energy_defense = 35
	var enemy := EnemyCombatant.new()
	add_child_autofree(enemy)
	enemy.setup_base(stats, BattleCombatant.Faction.ENEMY)
	return enemy
