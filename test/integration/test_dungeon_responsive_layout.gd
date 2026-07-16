extends GutTest

const ResponsiveFixture = preload("res://test/fixtures/responsive_viewport_fixture.gd")
const DungeonMapScene = preload("res://src/map/dungeon_map.tscn")
const DungeonEndScreenScene = preload("res://src/map/dungeon_end_screen.tscn")

const ACCEPTANCE_OUTPUTS: Array[Vector2i] = [
	Vector2i(1280, 800),
	Vector2i(1920, 1080),
]


func test_dungeon_hud_groups_use_owned_anchors_and_fit_acceptance_outputs() -> void:
	for window_size in ACCEPTANCE_OUTPUTS:
		var dungeon_map := await _dungeon_map_in_viewport(window_size)
		var hud := dungeon_map.get_node("CanvasLayer/HUD") as Control
		assert_eq(hud.get_global_rect(), Rect2(Vector2.ZERO, ResponsiveFixture.logical_size_for(window_size)))
		for path in ["AlertGauge", "TeamStatus", "BitsFound", "NodeGauge", "Warning"]:
			assert_true(
				ResponsiveFixture.fits_output(hud.get_node(path), window_size),
				"%s must fit %s" % [path, window_size],
			)

		_assert_anchor(hud.get_node("TeamStatus"), Vector2.ZERO, "TeamStatus")
		_assert_anchor(hud.get_node("BitsFound"), Vector2.ZERO, "BitsFound")
		_assert_anchor(hud.get_node("AlertGauge"), Vector2(1.0, 0.0), "AlertGauge")
		_assert_anchor(hud.get_node("NodeGauge"), Vector2(0.0, 1.0), "NodeGauge")
		_assert_anchor(hud.get_node("Warning"), Vector2(0.5, 0.0), "Warning")
		if window_size == Vector2i(1920, 1080):
			_assert_authored_desktop_rects(hud)


func test_dungeon_camera_refits_to_expanded_viewport_after_resize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	add_child_autofree(viewport)
	var dungeon_map := DungeonMapScene.instantiate() as DungeonMap
	viewport.add_child(dungeon_map)
	await get_tree().process_frame
	dungeon_map.camera.zoom = Vector2(0.5, 0.5)
	dungeon_map.camera.position = Vector2(100000, 100000)

	viewport.size = Vector2i(1920, 1200)
	await get_tree().process_frame

	var expected_zoom := dungeon_map.camera_controller.cover_zoom(Vector2(1920, 1200))
	assert_gte(dungeon_map.camera.zoom.x, expected_zoom.x)
	assert_eq(
		dungeon_map.camera.position,
		dungeon_map.camera_controller.clamp_position(
			dungeon_map.camera.position,
			dungeon_map.camera.zoom,
			Vector2(1920, 1200),
		),
	)


func test_dungeon_end_panel_is_centered_and_fits_acceptance_outputs() -> void:
	for window_size in ACCEPTANCE_OUTPUTS:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(ResponsiveFixture.logical_size_for(window_size))
		add_child_autofree(viewport)
		var end_screen := DungeonEndScreenScene.instantiate() as DungeonEndScreen
		viewport.add_child(end_screen)
		end_screen.apply_display_profile(
			DisplayProfileService.profile_for(window_size),
			window_size,
			viewport.size,
		)
		await get_tree().process_frame
		var panel := end_screen.get_node("Panel") as Control

		assert_true(ResponsiveFixture.fits_output(panel, window_size))
		assert_almost_eq(panel.position.x + panel.size.x * 0.5, viewport.size.x * 0.5, 0.01)
		assert_almost_eq(panel.position.y + panel.size.y * 0.5, viewport.size.y * 0.5, 0.01)
		assert_lte(panel.size.x, viewport.size.x - 96.0)
		assert_lte(panel.size.y, viewport.size.y - 96.0)


func _dungeon_map_in_viewport(window_size: Vector2i) -> DungeonMap:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ResponsiveFixture.logical_size_for(window_size))
	add_child_autofree(viewport)
	var dungeon_map := DungeonMapScene.instantiate() as DungeonMap
	viewport.add_child(dungeon_map)
	await get_tree().process_frame
	return dungeon_map


func _assert_anchor(control: Control, expected: Vector2, label: String) -> void:
	assert_eq(control.anchor_left, expected.x, "%s left anchor" % label)
	assert_eq(control.anchor_right, expected.x, "%s right anchor" % label)
	assert_eq(control.anchor_top, expected.y, "%s top anchor" % label)
	assert_eq(control.anchor_bottom, expected.y, "%s bottom anchor" % label)


func _assert_authored_desktop_rects(hud: Control) -> void:
	assert_eq(hud.get_node("AlertGauge").get_global_rect(), Rect2(144, 10, 425, 40))
	assert_eq(hud.get_node("BitsFound").get_global_rect(), Rect2(1239, 10, 224, 40))
	assert_eq(hud.get_node("NodeGauge").get_global_rect(), Rect2(1476, 10, 189, 40))
	assert_eq(hud.get_node("TeamStatus").get_global_rect(), Rect2(18, 1029, 1884, 40))
