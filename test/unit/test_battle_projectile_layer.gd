extends GutTest


const PROJECTILE_SCENE := preload(
	"res://src/battle/presentation/battle_projectile_layer.tscn",
)


func after_each() -> void:
	for tween: Tween in get_tree().get_processed_tweens():
		tween.kill()


func test_laser_starts_and_ends_at_requested_screen_positions() -> void:
	var layer := _projectile_layer()
	var operation := layer.fire_laser(
		Vector2(300, 200), Vector2(900, 700), Color.CYAN,
	)

	assert_eq(layer.active_lasers.size(), 1)
	assert_eq(layer.active_lasers[0].points[0], Vector2(300, 200))
	assert_eq(layer.active_lasers[0].points[1], Vector2(900, 700))
	await operation.completed
	await get_tree().process_frame
	assert_true(layer.active_lasers.is_empty())


func test_freeing_layer_completes_pending_laser_operation() -> void:
	var layer := _projectile_layer(60.0)
	var operation := layer.fire_laser(Vector2.ZERO, Vector2.ONE, Color.RED)

	layer.free()
	await get_tree().process_frame

	assert_true(operation.is_completed)


func test_teardown_clears_every_registry_before_publishing_completion() -> void:
	var layer := _projectile_layer(60.0)
	var operation := layer.fire_laser(Vector2.ZERO, Vector2.ONE, Color.RED)
	var observed_sizes: Array[Vector3i] = []
	operation.completed.connect(
		func() -> void:
			observed_sizes.append(Vector3i(
				layer.active_lasers.size(),
				layer.active_tweens.size(),
				layer._active_operations.size(),
			))
	)

	layer.free()

	assert_eq(observed_sizes, [Vector3i.ZERO])


func test_completion_callback_cannot_reenter_a_tearing_down_layer() -> void:
	var layer := _projectile_layer(60.0)
	var operation := layer.fire_laser(Vector2.ZERO, Vector2.ONE, Color.RED)
	var reentrant_operations: Array[PresentationOperation] = []
	var observed_sizes: Array[Vector3i] = []
	operation.completed.connect(
		func() -> void:
			reentrant_operations.append(layer.fire_laser(
				Vector2(10, 20), Vector2(30, 40), Color.CYAN,
			))
			observed_sizes.append(Vector3i(
				layer.active_lasers.size(),
				layer.active_tweens.size(),
				layer._active_operations.size(),
			))
	)

	layer.free()

	assert_eq(reentrant_operations.size(), 1)
	assert_true(reentrant_operations[0].is_completed)
	assert_eq(observed_sizes, [Vector3i.ZERO])


func _projectile_layer(duration := 0.12) -> BattleProjectileLayer:
	var layer := PROJECTILE_SCENE.instantiate() as BattleProjectileLayer
	layer.laser_duration = duration
	add_child_autofree(layer)
	return layer
