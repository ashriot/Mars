extends Control
class_name LoadingScreen

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var label: Label = $VBoxContainer/Label

# Tweak this: How long to wait before showing the screen?
# 0.15s is usually enough to catch "instant" loads.
const GRACE_PERIOD: float = 0.15

var _is_finished: bool = false
var _grace_timer_done: bool = false

func _ready():
	# 1. Start INVISIBLE and blocking input
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0

	# 2. Start the "Grace Period" timer
	await get_tree().create_timer(GRACE_PERIOD).timeout
	_grace_timer_done = true

	# 3. Decision Time: Are we still loading?
	if not _is_finished:
		# Yes, we are still loading. Fade IN the screen.
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.2)

func update_progress(current: int, total: int):
	progress_bar.max_value = total
	progress_bar.value = current

	var percent = int((float(current) / float(total)) * 100)
	label.text = "Generating Sector... %d%%" % percent

	if current >= total:
		_finish_loading()

func _finish_loading():
	_is_finished = true

	# Case A: We finished FAST (before the grace timer ended).
	# The screen is still invisible (alpha 0).
	if modulate.a == 0.0:
		# Just delete instantly. The player never saw us.
		queue_free()

	# Case B: We finished SLOW (screen is visible).
	else:
		# Do a nice fade out.
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.25)
		await tween.finished
		queue_free()
