extends Control
class_name DamagePopup

@onready var label = $Label

# --- 1. Define all your animation "tweak" variables here ---
const FALL_DURATION = 0.5
const FALL_DISTANCE = 300.0

# Crit parameters
const CRIT_POP_SCALE = Vector2(2.0, 2.0)
const CRIT_POP_DURATION = 0.4
const CRIT_LINGER_DURATION = 0.4

# Normal parameters
const NORMAL_POP_SCALE = Vector2(1.3, 1.3)
const NORMAL_POP_DURATION = 0.2
const NORMAL_LINGER_DURATION = 0.2

func show_damage(amount: int, damage_type: Action.DamageType, speed: float, is_crit := false):
	label.text = str(amount)

	# --- 2. Define variables based on 'is_crit' ---
	var pop_scale: Vector2
	var pop_duration: float
	var linger_duration: float
	var base_color = Color.WHITE
	match damage_type:
		Action.DamageType.KINETIC:
			base_color = Color.ORANGE_RED
		Action.DamageType.ENERGY:
			base_color = Color.CYAN
		Action.DamageType.PIERCING:
			base_color = Color.MAGENTA

	if is_crit:
		pop_scale = CRIT_POP_SCALE
		pop_duration = CRIT_POP_DURATION / speed
		linger_duration = CRIT_LINGER_DURATION / speed
		label.text += "!"
	else:
		pop_scale = NORMAL_POP_SCALE
		pop_duration = NORMAL_POP_DURATION / speed
		linger_duration = NORMAL_LINGER_DURATION / speed

	# --- 3. Set initial state ---
	label.modulate = base_color
	# Store the initial position
	var start_y = position.y

	# --- 4. Create the main animation chain ---
	var tween = create_tween().set_trans(Tween.TRANS_SINE)

	# 4a. "Pop" up
	tween.tween_property(
		self, "scale", pop_scale, pop_duration
	).set_ease(Tween.EASE_OUT)

	# 4b. "Settle" back down AND fade from flash
	var settle_tween = tween.parallel()
	settle_tween.tween_property(
		self, "scale", Vector2(1.0, 1.0), linger_duration
	)
	settle_tween.tween_property(
		label, "modulate", base_color, linger_duration
	)

	# 4c. "Fall" AND "Fade Out" - these run in parallel
	# Chain after settle, but make the two animations parallel to each other
	var distance = FALL_DISTANCE
	tween.tween_property(
		self, "position:y", start_y + distance, FALL_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# This runs in parallel with the position change above
	tween.parallel().tween_property(
		label, "modulate:a", 0.0, FALL_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# --- 5. Self-Destruct ---
	tween.finished.connect(queue_free)
