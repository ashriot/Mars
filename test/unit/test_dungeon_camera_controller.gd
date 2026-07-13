extends GutTest


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
