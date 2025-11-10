# ActorQueue.gd
extends Control
class_name ActorQueue

@onready var name_label: Label = $NameLabel
@onready var ct_bar_1: ProgressBar = $CT/Bar1
@onready var ct_bar_2: ProgressBar = $CT/Bar2
@onready var ct_bar_3: ProgressBar = $CT/Bar3


const TICK_SEGMENT_COST: int = 80

func setup(actor: ActorCard, ticks: int):
	$NameLabel.text = actor.current_stats.actor_name

	$CtLabel.text = str(ticks)

	# 2. Set the max value for all 3 bars
	# This makes "20" the 100% mark for each bar.
	ct_bar_1.max_value = TICK_SEGMENT_COST
	ct_bar_2.max_value = TICK_SEGMENT_COST
	ct_bar_3.max_value = TICK_SEGMENT_COST

	ct_bar_1.value = max(0, min(ticks, TICK_SEGMENT_COST))
	var bar_ratio = float(ct_bar_1.value) / TICK_SEGMENT_COST
	if ct_bar_1.value < TICK_SEGMENT_COST:
		ct_bar_1.max_value = ct_bar_1.value
		$CT.size.x = ct_bar_1.value

	name_label.position.x = bar_ratio * name_label.size.x + 20

	ct_bar_2.value = max(0, min(ticks - TICK_SEGMENT_COST, TICK_SEGMENT_COST))
	ct_bar_2.visible = ticks > TICK_SEGMENT_COST

	ct_bar_3.value = max(0, min(ticks - (TICK_SEGMENT_COST * 2), TICK_SEGMENT_COST))
	ct_bar_3.visible = ticks > TICK_SEGMENT_COST * 2
