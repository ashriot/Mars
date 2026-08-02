extends Node2D
class_name FXManager

# Assign your .tscn files here in the Inspector
@export var impact_sparks: PackedScene
@export var shield_hit: PackedScene

var camera_rig: BattleCameraRig

# Play sparks at the victim's position
func play_hit_effect(target_pos: Vector2, is_shield_hit: bool = false):
	var scene_to_use = shield_hit if is_shield_hit else impact_sparks
	if not scene_to_use: return

	var fx = scene_to_use.instantiate()
	add_child(fx)
	fx.global_position = target_pos
	fx.emitting = true

# Optional: Add a little screen shake for heavy hits
func trigger_shake(intensity: float) -> void:
	if is_instance_valid(camera_rig):
		camera_rig.request_shake(intensity)
