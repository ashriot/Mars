extends PanelContainer
class_name FloatingText

@onready var label: RichTextLabel = $MarginContainer/Content/Label
@onready var icon: TextureRect = $MarginContainer/Content/Icon


const LINGER_DURATION: float = 1.0
const FADE_DURATION: float = 0.5
const FLOAT_DISTANCE: float = 60.0

func setup(pos: Vector2, text: String, texture: Texture2D = null, color: Color = Color.WHITE, scale_mult: float = 1.0):
	pivot_offset = Vector2(size.x / 2, size.y / 2)
	global_position = pos + Vector2(size.x / -2, -150)
	# 1. Set Content
	label.text = "[center] %s[/center]" % text
	icon.texture = texture

	# 2. Visual Setup
	self.self_modulate = color
	self.scale = Vector2.ZERO

	_play_animation(scale_mult)

func _play_animation(target_scale: float):
	var pop_duration = 0.25

	# Calculate exactly when the "End" sequence should start
	var fade_start_time = pop_duration + LINGER_DURATION

	var tween = create_tween()
	tween.set_parallel(true) # Everything runs on the same timeline

	tween.tween_property(self, "scale", Vector2(target_scale, target_scale), pop_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var target_y = position.y - FLOAT_DISTANCE

	# Float Up
	tween.tween_property(self, "position:y", target_y, FADE_DURATION)\
		.set_delay(fade_start_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Fade Out
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)\
		.set_delay(fade_start_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# --- 3. CLEANUP ---
	tween.finished.connect(queue_free)
