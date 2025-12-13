# TurnQueue.gd
extends Control
class_name TurnQueue

@export var actor_queue_scene: PackedScene
@export var battle_manager: BattleManager
@onready var queue := $Queue

const QUEUE_ITEM_HEIGHT: int = 40  # Adjust to match your ActorQueue scene height
const QUEUE_ITEM_SPACING: int = 4
const ANIMATION_DURATION: float = 0.3

var queue_items: Array[ActorQueue] = []  # All visible queue items in order

func _ready():
	battle_manager.turn_order_updated.connect(_on_turn_order_updated)

	# Make sure queue is a plain Control node
	if not (queue is Control and not queue is Container):
		push_error("Queue must be a plain Control node for manual positioning!")

func _on_turn_order_updated(projected_queue: Array, animate: bool = true):
	if projected_queue.is_empty():
		_clear_queue()
		return

	# Calculate the scale for the bars
	var ticks_per_bar = _calculate_ticks_per_bar(projected_queue)
	var first_turn_ticks = projected_queue[0].ticks_needed

	# Display up to 7 turns (can include same actor multiple times)
	var display_count = min(projected_queue.size(), 7)

	# Adjust queue item count to match display count
	_adjust_queue_size(display_count)

	for i in range(display_count):
		var turn_data = projected_queue[i]
		var actor: ActorCard = turn_data.actor

		# Calculate position and bar values
		var target_y = i * (QUEUE_ITEM_HEIGHT + QUEUE_ITEM_SPACING)
		var relative_ticks = turn_data.ticks_needed - first_turn_ticks
		var bar_position = relative_ticks / ticks_per_bar
		var is_current = (i == 0)

		# Update the queue item at this position
		var queue_item = queue_items[i]
		queue_item.setup(actor, bar_position, int(relative_ticks), animate, is_current)

		# Update position (animate or instant)
		if animate:
			_animate_position(queue_item, target_y)
		else:
			queue_item.position.y = target_y

		# Show "next" indicator on second actor
		if i == 1:
			actor.show_next()
		elif i > 1:
			actor.next_panel.hide()

func _adjust_queue_size(target_count: int):
	"""Add or remove queue items to match the target count"""
	# Remove excess items
	while queue_items.size() > target_count:
		var item = queue_items.pop_back()
		item.queue_free()

	# Add missing items
	while queue_items.size() < target_count:
		var queue_item = actor_queue_scene.instantiate() as ActorQueue
		queue.add_child(queue_item)
		queue_items.append(queue_item)

func _clear_queue():
	"""Remove all queue items"""
	for item in queue_items:
		item.queue_free()
	queue_items.clear()

func _animate_position(queue_item: ActorQueue, target_y: float):
	"""Smoothly move a queue item to its target position"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(queue_item, "position:y", target_y, ANIMATION_DURATION)

func _calculate_ticks_per_bar(projection: Array) -> float:
	"""Calculate how many actual ticks each bar should represent"""
	if projection.size() < 2:
		return _get_average_ticks_per_turn() / 3.0

	var first_ticks = projection[0].ticks_needed
	var last_visible_idx = min(6, projection.size() - 1)
	var last_ticks = projection[last_visible_idx].ticks_needed
	var visible_range = last_ticks - first_ticks

	return max(visible_range / 3.0, 10.0)

func _get_average_ticks_per_turn() -> float:
	"""Fallback calculation for tick scale"""
	if not battle_manager or not battle_manager.actor_list:
		return 100.0

	var total_speed = 0.0
	for actor in battle_manager.actor_list:
		total_speed += actor.get_speed()

	if total_speed == 0:
		return 100.0

	var avg_speed = total_speed / float(battle_manager.actor_list.size())
	return battle_manager.TARGET_CT / avg_speed
