# ActorQueue.gd
extends Control
class_name ActorQueue

@onready var name_label: Label = $NameLabel
@onready var ct_label: Label = $CtLabel
@onready var ct_bar_1: ProgressBar = $CT/Bar1
@onready var ct_bar_2: ProgressBar = $CT/Bar2
@onready var ct_bar_3: ProgressBar = $CT/Bar3
@onready var current_turn: Control = $CurrentTurn

const BAR_WIDTH_PX: int = 50
const ANIMATION_DURATION: float = 0.3

var active_tweens: Array[Tween] = []
var actor_ref: ActorCard

func setup(actor: ActorCard, bar_position: float, actual_ticks: int, animate: bool, is_current: bool = false):
	actor_ref = actor
	name_label.text = actor.actor_name

	# Show the actual tick value
	#if is_current:
		#$CtLabel.text = "NOW "
	#else:
		#$CtLabel.text = str(actual_ticks) + " "
	ct_label.text = ""

	current_turn.visible = is_current

	_kill_all_tweens()

	ct_bar_1.max_value = 1.0
	ct_bar_2.max_value = 1.0
	ct_bar_3.max_value = 1.0

	# Calculate target values
	var target_bar1: float = 0.0
	var target_bar2: float = 0.0
	var target_bar3: float = 0.0
	var show_bar1: bool = false
	var show_bar2: bool = false
	var show_bar3: bool = false
	var target_width: float = 0.0

	if bar_position <= 1.0:
		# Only first bar visible, partially filled
		target_bar1 = bar_position
		show_bar1 = true
		target_width = bar_position * BAR_WIDTH_PX

	elif bar_position <= 2.0:
		# First bar full, second bar partially filled
		target_bar1 = 1.0
		target_bar2 = bar_position - 1.0
		show_bar1 = true
		show_bar2 = true
		target_width = BAR_WIDTH_PX

	elif bar_position <= 3.0:
		# First two bars full, third bar partially filled
		target_bar1 = 1.0
		target_bar2 = 1.0
		target_bar3 = bar_position - 2.0
		show_bar1 = true
		show_bar2 = true
		show_bar3 = true
		target_width = BAR_WIDTH_PX

	else:
		# All bars full
		target_bar1 = 1.0
		target_bar2 = 1.0
		target_bar3 = 1.0
		show_bar1 = true
		show_bar2 = true
		show_bar3 = true
		target_width = BAR_WIDTH_PX

	# Apply values immediately or animate
	if animate:
		_animate_to_values(target_bar1, target_bar2, target_bar3,
						   show_bar1, show_bar2, show_bar3, target_width)
	else:
		_set_values_instantly(target_bar1, target_bar2, target_bar3,
							  show_bar1, show_bar2, show_bar3, target_width)

func _animate_to_values(bar1: float, bar2: float, bar3: float,
						show1: bool, show2: bool, show3: bool, width: float):
	"""Tween the bars to their target values"""

	# Show bars immediately if they need to appear (visibility doesn't tween well)
	ct_bar_1.visible = show1
	ct_bar_2.visible = show2
	ct_bar_3.visible = show3

	# Create tween for bar values
	var tween = create_tween()
	tween.set_parallel(true)  # All tweens happen simultaneously
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	if show1:
		tween.tween_property(ct_bar_1, "value", bar1, ANIMATION_DURATION)
	if show2:
		tween.tween_property(ct_bar_2, "value", bar2, ANIMATION_DURATION)
	if show3:
		tween.tween_property(ct_bar_3, "value", bar3, ANIMATION_DURATION)

	# Tween container width
	tween.tween_property($CT, "custom_minimum_size:x", width, ANIMATION_DURATION)

	active_tweens.append(tween)

func _set_values_instantly(bar1: float, bar2: float, bar3: float,
						   show1: bool, show2: bool, show3: bool, width: float):
	"""Set bar values without animation"""

	ct_bar_1.value = bar1
	ct_bar_2.value = bar2
	ct_bar_3.value = bar3

	ct_bar_1.visible = show1
	ct_bar_2.visible = show2
	ct_bar_3.visible = show3

	$CT.custom_minimum_size.x = width

func _kill_all_tweens():
	"""Stop any active tweens to prevent conflicts"""
	for tween in active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	active_tweens.clear()
