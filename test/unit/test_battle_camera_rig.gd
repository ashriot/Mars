extends GutTest


var _saved_input_mode: InputManager.InputMode
var _saved_presentation_mode: InputManager.PresentationMode
var _saved_shake_intensity: float


func before_each() -> void:
	_saved_input_mode = InputManager.get_active_mode()
	_saved_presentation_mode = InputManager.get_presentation_mode()
	_saved_shake_intensity = CombatPresentationSettings.shake_intensity
	CombatPresentationSettings.set_shake_intensity(1.0, false)


func after_each() -> void:
	InputManager.restore_active_mode(_saved_input_mode)
	InputManager._set_presentation_mode(_saved_presentation_mode)
	CombatPresentationSettings.set_shake_intensity(_saved_shake_intensity, false)
	for tween: Tween in get_tree().get_processed_tweens():
		tween.kill()


func test_edge_rotation_is_centered_clamped_and_symmetric() -> void:
	var rig := BattleCameraRig.new()
	autofree(rig)
	var viewport_size := Vector2(1920, 1080)

	assert_eq(rig.edge_rotation_for(viewport_size * 0.5, viewport_size), Vector2.ZERO)
	var left := rig.edge_rotation_for(Vector2.ZERO, viewport_size)
	var right := rig.edge_rotation_for(Vector2(1920, 0), viewport_size)
	assert_almost_eq(left.y, -right.y, 0.0001)
	assert_true(absf(left.x) <= rig.max_pitch_radians)
	assert_true(
		absf(left.y) <= rig.max_yaw_radians,
		"left yaw %s max %s" % [left.y, rig.max_yaw_radians],
	)


func test_zero_motion_setting_disables_shake() -> void:
	var rig := BattleCameraRig.new()
	autofree(rig)
	rig.shake_scale = 0.0

	rig.request_shake(1.0)

	assert_eq(rig.trauma, 0.0)
	assert_eq(rig.transform, Transform3D.IDENTITY)


func test_trauma_is_scaled_by_local_and_shared_intensity() -> void:
	var rig := BattleCameraRig.new()
	autofree(rig)
	rig.shake_scale = 0.5
	CombatPresentationSettings.set_shake_intensity(0.5, false)

	rig.request_shake(0.8)

	assert_eq(rig.trauma, 0.2)


func test_shared_zero_setting_keeps_camera_transform_and_trauma_unchanged() -> void:
	var rig := BattleCameraRig.new()
	autofree(rig)
	CombatPresentationSettings.set_shake_intensity(0.0, false)
	var neutral_transform := rig.transform

	rig.request_shake(1.0)

	assert_eq(rig.trauma, 0.0)
	assert_eq(rig.transform, neutral_transform)


func test_controller_ownership_ignores_pointer_at_viewport_edge() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	add_child_autofree(viewport)
	var rig := BattleCameraRig.new()
	viewport.add_child(rig)
	rig.set_pointer_screen_position(Vector2.ZERO)
	InputManager.restore_active_mode(InputManager.InputMode.CONTROLLER)
	InputManager._set_presentation_mode(InputManager.PresentationMode.FOCUS)

	rig._process(0.1)

	assert_eq(rig.edge_rotation_target, Vector2.ZERO)
