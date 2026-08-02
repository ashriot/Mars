extends CanvasLayer
class_name BattleProjectileLayer

@export_range(0.01, 5.0, 0.01) var laser_duration := 0.12
@export_range(1.0, 32.0, 0.5) var laser_width := 5.0

@onready var effect_root: Control = %EffectRoot

var active_lasers: Array[Line2D] = []
var active_tweens: Dictionary = {}
var _active_operations: Dictionary = {}


func _exit_tree() -> void:
	for operation_value: Variant in _active_operations.keys():
		var operation := operation_value as PresentationOperation
		var tween := active_tweens.get(operation) as Tween
		if tween != null and tween.is_valid():
			tween.kill()
		operation.complete()
	active_lasers.clear()
	active_tweens.clear()
	_active_operations.clear()


func fire_laser(
	from_screen: Vector2,
	to_screen: Vector2,
	color: Color,
) -> PresentationOperation:
	if not is_instance_valid(effect_root) or not is_inside_tree():
		return PresentationOperation.already_completed()
	var laser := Line2D.new()
	laser.name = "Laser"
	laser.points = PackedVector2Array([from_screen, to_screen])
	laser.width = laser_width
	laser.default_color = color
	laser.antialiased = true
	effect_root.add_child(laser)
	active_lasers.append(laser)
	var operation := PresentationOperation.new()
	_active_operations[operation] = laser
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tweens[operation] = tween
	tween.tween_property(laser, "modulate:a", 0.0, laser_duration)
	tween.finished.connect(_complete_laser.bind(operation), CONNECT_ONE_SHOT)
	return operation


func _complete_laser(operation: PresentationOperation) -> void:
	if not _active_operations.has(operation):
		return
	var laser := _active_operations[operation] as Line2D
	_active_operations.erase(operation)
	active_tweens.erase(operation)
	active_lasers.erase(laser)
	if is_instance_valid(laser):
		laser.queue_free()
	operation.complete()
