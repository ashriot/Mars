extends Control
class_name TurnQueue

@export var actor_queue_scene: PackedScene
@export var battle_manager: BattleManager
@onready var queue := $Queue

const QUEUE_ITEM_HEIGHT: int = 40
const QUEUE_ITEM_SPACING: int = 4
const ANIMATION_DURATION: float = 0.3

const SLIDE_OFFSET_X = 50.0

var queue_items: Array[ActorQueue] = []

func _ready():
	battle_manager.turn_order_updated.connect(_on_turn_order_updated)

func _on_turn_order_updated(projected_queue: Array, animate: bool = true):
	if projected_queue.is_empty():
		_clear_queue()
		return

	# 1. Snapshot the Old State
	var old_items = queue_items.duplicate()
	queue_items.clear()

	var exiting_item: ActorQueue = null

	if not old_items.is_empty() and animate:
		if old_items[0].actor_ref != projected_queue[0].actor:
			exiting_item = old_items.pop_front() # Remove top item

	# 3. Handle the Exiting Item
	if exiting_item:
		_animate_exit(exiting_item)

	# 4. Rebuild the List
	var ticks_per_bar = _calculate_ticks_per_bar(projected_queue)
	var first_turn_ticks = projected_queue[0].ticks_needed

	# We limit the display count to keep the UI clean (e.g., 10 items max)
	# or just use the projection size provided by the manager (usually 10).
	var display_count = projected_queue.size()

	for i in range(display_count):
		var turn_data = projected_queue[i]
		var actor = turn_data.actor

		# Calculate target Y immediately
		var target_y = i * (QUEUE_ITEM_HEIGHT + QUEUE_ITEM_SPACING)

		# A. Find existing
		var item_ui: ActorQueue = _find_and_pop_match(actor, old_items)
		var is_new_instance = false

		# B. Create New if needed
		if not item_ui:
			item_ui = actor_queue_scene.instantiate() as ActorQueue
			queue.add_child(item_ui)
			is_new_instance = true
			item_ui.position.y = target_y

			if animate:
				item_ui.position.x = SLIDE_OFFSET_X
				item_ui.modulate.a = 0.0

		# C. Setup Data
		var relative_ticks = turn_data.ticks_needed - first_turn_ticks
		var bar_pos = relative_ticks / ticks_per_bar

		item_ui.setup(actor, bar_pos, int(relative_ticks), animate, i == 0)
		queue_items.append(item_ui)

		# D. Animate
		if animate:
			_animate_to_target(item_ui, target_y, is_new_instance)
		else:
			# Instant Snap
			item_ui.position.y = target_y
			item_ui.position.x = 0
			item_ui.modulate.a = 1.0

	# 5. Cleanup unused
	for unused_item in old_items:
		_animate_exit(unused_item)

# --- HELPERS ---

func _find_and_pop_match(actor: ActorCard, pool: Array) -> ActorQueue:
	for i in range(pool.size()):
		if pool[i].actor_ref == actor:
			var item = pool[i]
			pool.remove_at(i)
			return item
	return null

func _animate_exit(item: ActorQueue):
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(item, "modulate:a", 0.0, ANIMATION_DURATION / 3.0)
	tween.chain().tween_callback(item.queue_free)

func _animate_to_target(item: ActorQueue, target_y: float, is_new: bool):
	var tween = create_tween().set_parallel()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(item, "position:y", target_y, ANIMATION_DURATION)

	if item.position.x != 0:
		tween.tween_property(item, "position:x", 0.0, ANIMATION_DURATION)
	if is_new:
		tween.tween_property(item, "modulate:a", 1.0, ANIMATION_DURATION)

func _calculate_ticks_per_bar(projection: Array) -> float:
	if projection.size() < 2: return 100.0
	var first = projection[0].ticks_needed
	var last = projection[min(6, projection.size() - 1)].ticks_needed
	return max((last - first) / 3.0, 10.0)

func _clear_queue():
	for item in queue_items: item.queue_free()
	queue_items.clear()
