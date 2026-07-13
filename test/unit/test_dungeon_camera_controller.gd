extends GutTest


func test_freeing_off_tree_dungeon_map_leaves_no_live_camera_controller() -> void:
	var dungeon_map := DungeonMap.new()
	var controller := dungeon_map.camera_controller
	dungeon_map.free()

	assert_false(is_instance_valid(controller))
	if is_instance_valid(controller):
		controller.free()


func _fixture() -> Dictionary:
	var controller := DungeonCameraController.new()
	var camera := Camera2D.new()
	var background := Sprite2D.new()
	var parallax := Parallax2D.new()
	background.texture = ImageTexture.create_from_image(
		Image.create(1200, 900, false, Image.FORMAT_RGBA8)
	)
	background.scale = Vector2(2.0, 2.0)
	parallax.scroll_scale = Vector2(0.5, 0.5)
	add_child_autofree(controller)
	add_child_autofree(camera)
	add_child_autofree(background)
	add_child_autofree(parallax)
	controller.configure(camera, background, parallax)
	return {
		"controller": controller,
		"camera": camera,
		"background": background,
		"parallax": parallax,
	}


func test_clamp_position_preserves_inside_position_and_clamps_each_edge() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var viewport := Vector2(900, 600)
	assert_eq(controller.clamp_position(Vector2.ZERO, Vector2.ONE, viewport), Vector2.ZERO)
	var positive := controller.clamp_position(Vector2(100000, 100000), Vector2.ONE, viewport)
	var negative := controller.clamp_position(Vector2(-100000, -100000), Vector2.ONE, viewport)
	assert_gt(positive.x, 0.0)
	assert_gt(positive.y, 0.0)
	assert_eq(negative, -positive)


func test_clamp_position_centers_axis_when_viewport_exceeds_background() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	assert_eq(
		controller.clamp_position(Vector2(500, 500), Vector2(0.01, 0.01), Vector2(900, 600)),
		Vector2.ZERO,
	)


func test_pan_is_delta_scaled_zoom_adjusted_normalized_and_clamped() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.pan_speed = 100.0
	camera.zoom = Vector2(2.0, 2.0)
	camera.position = Vector2.ZERO
	var diagonal := controller.pan(Vector2(1, 1), 0.5, Vector2(900, 600))
	assert_almost_eq(diagonal.x, 70.71068, 0.001)
	assert_almost_eq(diagonal.y, 70.71068, 0.001)
	assert_eq(camera.position, diagonal)
	camera.position = Vector2(100000, 100000)
	var clamped := controller.pan(Vector2.RIGHT, 0.5, Vector2(900, 600))
	assert_eq(clamped, controller.clamp_position(clamped, camera.zoom, Vector2(900, 600)))


func test_recenter_clamps_party_position_at_current_zoom() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	camera.zoom = Vector2(1.5, 1.5)
	var expected := controller.clamp_position(Vector2(100000, -100000), camera.zoom, Vector2(900, 600))
	assert_eq(controller.recenter(Vector2(100000, -100000), Vector2(900, 600)), expected)
	assert_eq(camera.position, expected)


func test_scanner_dead_zone_scales_with_viewport_and_zoom() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	controller.scanner_dead_zone_ratio = Vector2(0.6, 0.6)
	assert_eq(
		controller.desired_scanner_position(Vector2(250, 200), Vector2.ZERO, Vector2(1000, 800), Vector2.ONE),
		Vector2.ZERO,
	)
	assert_eq(
		controller.desired_scanner_position(Vector2(200, 0), Vector2.ZERO, Vector2(1000, 800), Vector2(2, 2)),
		Vector2(50, 0),
	)
	assert_eq(
		controller.desired_scanner_position(Vector2(350, 0), Vector2.ZERO, Vector2(2000, 800), Vector2.ONE),
		Vector2.ZERO,
	)


func test_fractional_scanner_dead_zone_preserves_inside_and_outside_boundary() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	controller.scanner_dead_zone_ratio = Vector2(0.6, 0.6)
	var viewport_size := Vector2(1001, 800)
	var zoom := Vector2(1.7, 1.7)
	var boundary := viewport_size.x * controller.scanner_dead_zone_ratio.x * 0.5 / zoom.x
	assert_eq(
		controller.desired_scanner_position(
			Vector2(boundary - 0.00003, 0),
			Vector2.ZERO,
			viewport_size,
			zoom,
		),
		Vector2.ZERO,
	)
	var outside_target := controller.desired_scanner_position(
		Vector2(boundary + 0.00003, 0),
		Vector2.ZERO,
		viewport_size,
		zoom,
	)
	assert_gt(outside_target.x, 0.0)
	assert_almost_eq(outside_target.x, 0.00003, 0.0001)


func test_follow_scanner_uses_exponential_response_without_overshoot() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.scanner_dead_zone_ratio = Vector2(0.1, 0.1)
	controller.scanner_follow_response = 8.0
	controller.set_focus_mode(DungeonCameraController.FocusMode.SCANNER)
	var scanner := Vector2(400, 300)
	var desired := controller.desired_scanner_position(
		scanner, camera.position, Vector2(1000, 800), camera.zoom
	)
	var expected := controller.clamp_position(
		camera.position.lerp(desired, 1.0 - exp(-8.0 * 0.125)),
		camera.zoom,
		Vector2(1000, 800),
	)
	assert_eq(controller.follow_scanner(scanner, 0.125, Vector2(1000, 800)), expected)
	assert_gt(camera.position.distance_to(desired), 0.0)


func test_party_focus_does_not_follow_scanner() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.set_focus_mode(DungeonCameraController.FocusMode.PARTY)
	assert_eq(controller.follow_scanner(Vector2(400, 300), 1.0, Vector2(1000, 800)), Vector2.ZERO)
	assert_eq(camera.position, Vector2.ZERO)


func test_cover_zoom_and_hybrid_position_preserve_existing_formula() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var cover := controller.cover_zoom(Vector2(900, 600))
	assert_eq(cover, Vector2.ONE * maxf(900.0 / 2400.0, 600.0 / 1800.0) * 1.02)
	assert_eq(controller.hybrid_position(Vector2(300, 150), cover, Vector2(900, 600)), Vector2.ZERO)
	assert_eq(controller.hybrid_position(Vector2(300, 150), Vector2.ONE, Vector2(900, 600)), Vector2(300, 150))


func test_party_zoom_tweens_zoom_and_hybrid_position() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.min_zoom = 0.5
	controller.max_zoom = 1.5
	controller.set_focus_mode(DungeonCameraController.FocusMode.PARTY)
	var final_zoom := controller.zoom_by(0.25, Vector2(300, 150), Vector2.ZERO, Vector2(900, 600))
	assert_eq(final_zoom, Vector2(1.25, 1.25))
	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout
	assert_eq(camera.zoom, final_zoom)
	assert_eq(camera.position, controller.hybrid_position(Vector2(300, 150), final_zoom, Vector2(900, 600)))


func test_zoom_stays_at_max_when_cover_zoom_exceeds_configured_range() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.max_zoom = 1.5
	camera.zoom = Vector2.ONE * controller.max_zoom
	var final_zoom := controller.zoom_by(
		0.25,
		Vector2.ZERO,
		Vector2.ZERO,
		Vector2(10000, 10000),
	)
	assert_eq(final_zoom, Vector2.ONE * controller.max_zoom)


func test_scanner_zoom_reframes_immediately_and_tweens_only_zoom() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	controller.max_zoom = 5.0
	camera.zoom = Vector2(4.0, 4.0)
	controller.set_focus_mode(DungeonCameraController.FocusMode.SCANNER)
	var scanner := Vector2(400, 300)
	var final_zoom := controller.zoom_by(1.0, Vector2(-300, -150), scanner, Vector2(900, 600))
	var expected_position := controller.clamp_position(
		controller.desired_scanner_position(scanner, Vector2.ZERO, Vector2(900, 600), final_zoom),
		final_zoom,
		Vector2(900, 600),
	)
	assert_eq(camera.position, expected_position)
	controller.follow_scanner(Vector2(450, 300), 0.5, Vector2(900, 600))
	var followed_position := camera.position
	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout
	assert_eq(camera.zoom, final_zoom)
	assert_eq(camera.position, followed_position)


func test_new_zoom_replaces_previous_camera_owned_motion() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	var viewport_size := Vector2(900, 600)
	controller.zoom_by(0.25, Vector2(300, 150), Vector2.ZERO, viewport_size)
	assert_true(controller.has_active_motion())
	var replacement_zoom := controller.zoom_by(
		-0.1,
		Vector2(-300, -150),
		Vector2.ZERO,
		viewport_size,
	)
	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout
	assert_eq(camera.zoom, replacement_zoom)
	assert_eq(
		camera.position,
		controller.hybrid_position(Vector2(-300, -150), replacement_zoom, viewport_size),
	)


func test_party_zoom_then_manual_pan_keeps_zoom_and_releases_position() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	var viewport_size := Vector2(900, 600)
	var final_zoom := controller.zoom_by(
		0.25,
		Vector2(300, 150),
		Vector2.ZERO,
		viewport_size,
	)
	var panned_position := controller.pan(Vector2.RIGHT, 0.1, viewport_size)
	assert_true(controller.has_active_motion())
	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout
	assert_eq(camera.zoom, final_zoom)
	assert_eq(camera.position, panned_position)


func test_zoom_out_then_manual_pan_reclamps_retained_position_at_final_zoom() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	var viewport_size := Vector2(900, 600)
	camera.zoom = Vector2(1.5, 1.5)
	var final_zoom := controller.zoom_by(
		-0.5,
		Vector2.ZERO,
		Vector2.ZERO,
		viewport_size,
	)
	var panned_position := controller.pan(Vector2.RIGHT, 100.0, viewport_size)
	var expected_final := controller.clamp_position(panned_position, final_zoom, viewport_size)
	assert_ne(panned_position, expected_final, "zoom-out fixture tightens the camera bounds")

	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout

	assert_eq(camera.zoom, final_zoom)
	assert_eq(camera.position, expected_final)


func test_party_zoom_then_recenter_keeps_zoom_and_releases_position() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	var viewport_size := Vector2(900, 600)
	var final_zoom := controller.zoom_by(
		0.25,
		Vector2(300, 150),
		Vector2.ZERO,
		viewport_size,
	)
	var recentered_position := controller.recenter(Vector2(-200, 100), viewport_size)
	assert_true(controller.has_active_motion())
	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout
	assert_eq(camera.zoom, final_zoom)
	assert_eq(camera.position, recentered_position)


func test_zoom_out_then_recenter_reclamps_retained_position_at_final_zoom() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	var viewport_size := Vector2(900, 600)
	camera.zoom = Vector2(1.5, 1.5)
	var final_zoom := controller.zoom_by(
		-0.5,
		Vector2.ZERO,
		Vector2.ZERO,
		viewport_size,
	)
	var recentered_position := controller.recenter(Vector2(100000, 0), viewport_size)
	var expected_final := controller.clamp_position(recentered_position, final_zoom, viewport_size)
	assert_ne(recentered_position, expected_final, "zoom-out fixture tightens the camera bounds")

	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout

	assert_eq(camera.zoom, final_zoom)
	assert_eq(camera.position, expected_final)


func test_party_zoom_then_scanner_follow_keeps_zoom_and_releases_position() -> void:
	var fixture := _fixture()
	var controller: DungeonCameraController = fixture.controller
	var camera: Camera2D = fixture.camera
	var viewport_size := Vector2(900, 600)
	controller.scanner_dead_zone_ratio = Vector2(0.1, 0.1)
	var final_zoom := controller.zoom_by(
		0.25,
		Vector2(-300, -150),
		Vector2.ZERO,
		viewport_size,
	)
	controller.set_focus_mode(DungeonCameraController.FocusMode.SCANNER)
	var followed_position := controller.follow_scanner(Vector2(400, 300), 0.5, viewport_size)
	assert_true(controller.has_active_motion())
	await get_tree().create_timer(DungeonCameraController.ZOOM_TWEEN_DURATION + 0.05).timeout
	assert_eq(camera.zoom, final_zoom)
	assert_eq(camera.position, followed_position)
