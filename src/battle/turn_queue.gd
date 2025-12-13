# TurnQueue.gd
extends Control
class_name TurnQueue

@export var actor_queue_scene: PackedScene
@export var battle_manager: BattleManager
@onready var queue := $Queue

const QUEUE_ITEM_HEIGHT: int = 40  # Adjust to match your ActorQueue scene height
const QUEUE_ITEM_SPACING: int = 4
const ANIMATION_DURATION: float = 0.3
const SLIDE_OFFSET_X = -200.0 # Slide left off-screen
const ENTER_OFFSET_X = 200.0  # Start right off-screen

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

	# 1. Snapshot the Old State
	var old_items = queue_items.duplicate()
	queue_items.clear() # We will rebuild this list

	# 2. Check for "Turn Cycle" (Did the top actor change?)
	# If the top actor is different, it means a turn finished (or was interrupted).
	# This triggers the "Slide Left" animation for the old top card.
	var is_turn_cycle = false
	var exiting_item: ActorQueue = null

	if not old_items.is_empty() and animate:
		# Compare the Actors, not the wrapper dictionaries
		if old_items[0].actor_ref != projected_queue[0].actor:
			is_turn_cycle = true
			exiting_item = old_items.pop_front() # Remove top item from pool

	# 3. Handle the Exiting Item (Slide Left)
	if exiting_item:
		_animate_exit(exiting_item)

	# 4. Rebuild the List (Match & Reuse)
	var ticks_per_bar = _calculate_ticks_per_bar(projected_queue)
	var first_turn_ticks = projected_queue[0].ticks_needed

	for i in range(projected_queue.size()):
		var turn_data = projected_queue[i]
		var actor = turn_data.actor

		# A. Find an existing UI panel for this actor
		var item_ui: ActorQueue = _find_and_pop_match(actor, old_items)
		var is_new_instance = false

		# B. If none found, create a new one
		if not item_ui:
			item_ui = actor_queue_scene.instantiate() as ActorQueue
			queue.add_child(item_ui)
			is_new_instance = true

			# Setup initial position for animation
			if animate:
				# If this is the "Cycling" actor (re-entering), start from Right
				if is_turn_cycle and exiting_item and actor == exiting_item.actor_ref:
					item_ui.position.x = ENTER_OFFSET_X
					item_ui.modulate.a = 0.0
				# Otherwise (spawned actor), just fade in
				else:
					item_ui.modulate.a = 0.0

		# C. Setup Data
		var target_y = i * (QUEUE_ITEM_HEIGHT + QUEUE_ITEM_SPACING)
		var relative_ticks = turn_data.ticks_needed - first_turn_ticks
		var bar_pos = relative_ticks / ticks_per_bar

		item_ui.setup(actor, bar_pos, int(relative_ticks), animate, i == 0)
		queue_items.append(item_ui)

		# D. Animate to Target Position
		if animate:
			_animate_to_target(item_ui, target_y, is_new_instance)
		else:
			# Instant Snap (for previews)
			item_ui.position.y = target_y
			item_ui.position.x = 0
			item_ui.modulate.a = 1.0

	# 5. Cleanup unused items (Faded/Removed actors)
	for unused_item in old_items:
		_animate_exit(unused_item) # Or just queue_free()

# --- HELPERS ---

func _find_and_pop_match(actor: ActorCard, pool: Array) -> ActorQueue:
	for i in range(pool.size()):
		if pool[i].actor_ref == actor:
			var item = pool[i]
			pool.remove_at(i)
			return item
	return null

func _animate_exit(item: ActorQueue):
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Slide Left
	tween.tween_property(item, "position:x", SLIDE_OFFSET_X, ANIMATION_DURATION)
	# Fade Out
	tween.tween_property(item, "modulate:a", 0.0, ANIMATION_DURATION)

	tween.chain().tween_callback(item.queue_free)

func _animate_to_target(item: ActorQueue, target_y: float, is_new: bool):
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 1. Move Y (Vertical Shift)
	tween.tween_property(item, "position:y", target_y, ANIMATION_DURATION)

	# 2. Reset X (If it was sliding in)
	if item.position.x != 0:
		tween.tween_property(item, "position:x", 0.0, ANIMATION_DURATION)

	# 3. Fade In (If new)
	if is_new:
		tween.tween_property(item, "modulate:a", 1.0, ANIMATION_DURATION)

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
