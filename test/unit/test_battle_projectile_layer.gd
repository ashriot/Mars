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


func _projectile_layer(duration := 0.12) -> BattleProjectileLayer:
	var layer := PROJECTILE_SCENE.instantiate() as BattleProjectileLayer
	layer.laser_duration = duration
	add_child_autofree(layer)
	return layer
