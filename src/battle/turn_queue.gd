extends Control
class_name TurnQueue


const ITEM_SPACING := 8
const RIGHT_STICK_DEAD_ZONE := 0.25
const RIGHT_STICK_SCROLL_SPEED := 700.0

@export var actor_queue_scene: PackedScene
@export var battle_manager: BattleManager

@onready var active_slot: Control = $ActiveSlot
@onready var future_scroll: ScrollContainer = $FutureScroll
@onready var future_content: Control = $FutureScroll/FutureContent
@onready var overflow_fade: TextureRect = $OverflowFade

var active_item: ActorQueue
var future_items: Array[ActorQueue] = []
var active_actor_ref: ActorCard
var _right_stick_y := 0.0
var _right_stick_scroll_residual := 0.0
var _right_stick_direction := 0
var _right_stick_max_scroll := -1


func _ready() -> void:
	if is_instance_valid(battle_manager):
		battle_manager.turn_order_updated.connect(_on_turn_order_updated)
	future_scroll.get_v_scroll_bar().value_changed.connect(_update_overflow_fade)
	call_deferred("_update_overflow_fade")


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
		_right_stick_y = event.axis_value


func _process(delta: float) -> void:
	scroll_future_by_axis(_right_stick_y, delta)


func scroll_future_by_axis(axis_value: float, delta: float) -> void:
	if absf(axis_value) < RIGHT_STICK_DEAD_ZONE:
		_reset_right_stick_scroll()
		return
	var direction := 1 if axis_value > 0.0 else -1
	if direction != _right_stick_direction:
		_right_stick_scroll_residual = 0.0
		_right_stick_direction = direction
	var max_scroll := _max_future_scroll()
	if max_scroll != _right_stick_max_scroll:
		_right_stick_scroll_residual = 0.0
		_right_stick_max_scroll = max_scroll
	var current_scroll := future_scroll.scroll_vertical
	if max_scroll == 0 or (direction < 0 and current_scroll == 0) or (
		direction > 0 and current_scroll == max_scroll
	):
		_right_stick_scroll_residual = 0.0
		return
	var movement := (
		axis_value * RIGHT_STICK_SCROLL_SPEED * delta
		+ _right_stick_scroll_residual
	)
	var whole_pixels := int(movement)
	_right_stick_scroll_residual = movement - whole_pixels
	if whole_pixels == 0:
		return
	var target_scroll := clampi(current_scroll + whole_pixels, 0, max_scroll)
	future_scroll.scroll_vertical = target_scroll
	if target_scroll == 0 or target_scroll == max_scroll:
		_right_stick_scroll_residual = 0.0


func _reset_right_stick_scroll() -> void:
	_right_stick_scroll_residual = 0.0
	_right_stick_direction = 0


func _setup_active(turn_data: Dictionary, _animate: bool) -> void:
	if active_item == null or active_item.actor_ref != turn_data.actor:
		if active_item:
			active_item.queue_free()
		active_item = actor_queue_scene.instantiate() as ActorQueue
		active_slot.add_child(active_item)
	active_item.setup(turn_data.actor, int(turn_data.ticks_needed), false, true, 0)
	active_item.position = Vector2(
		(active_slot.size.x - ActorQueue.ACTIVE_SIZE.x) * 0.5,
		0.0,
	)


func _on_turn_order_updated(projected_queue: Array, animate: bool = true) -> void:
	if projected_queue.is_empty():
		_clear_queue()
		return
	var new_active: ActorCard = projected_queue[0].actor
	var active_changed := active_actor_ref != new_active
	var saved_scroll := 0 if active_changed else future_scroll.scroll_vertical
	if active_changed:
		future_scroll.scroll_vertical = 0
	active_actor_ref = new_active
	_setup_active(projected_queue[0], animate)

	var occurrence_counts: Dictionary = {new_active: 1}
	var old_items := future_items.duplicate()
	future_items.clear()
	for index in range(1, projected_queue.size()):
		var turn_data: Dictionary = projected_queue[index]
		var actor: ActorCard = turn_data.actor
		var occurrence := int(occurrence_counts.get(actor, 0))
		occurrence_counts[actor] = occurrence + 1
		var item := _find_and_pop_match(actor, occurrence, old_items)
		if item == null:
			item = actor_queue_scene.instantiate() as ActorQueue
			future_content.add_child(item)
		item.setup(actor, int(turn_data.ticks_needed), animate, false, occurrence)
		var target := Vector2(
			(future_scroll.size.x - ActorQueue.FUTURE_SIZE.x) * 0.5,
			(index - 1) * (ActorQueue.FUTURE_SIZE.y + ITEM_SPACING),
		)
		if animate:
			item.animate_to(target)
		else:
			item.position = target
		future_items.append(item)

	var content_height := future_items.size() * int(ActorQueue.FUTURE_SIZE.y + ITEM_SPACING)
	if not future_items.is_empty():
		content_height -= ITEM_SPACING
	future_content.custom_minimum_size = Vector2(future_scroll.size.x, content_height)
	for unused: ActorQueue in old_items:
		unused.animate_exit()
	call_deferred("_restore_scroll", saved_scroll)


func _find_and_pop_match(actor: ActorCard, occurrence: int, pool: Array) -> ActorQueue:
	for index in pool.size():
		var candidate := pool[index] as ActorQueue
		if candidate.actor_ref == actor and candidate.occurrence_index == occurrence:
			pool.remove_at(index)
			return candidate
	return null


func _restore_scroll(value: int) -> void:
	future_scroll.scroll_vertical = clampi(value, 0, _max_future_scroll())
	_reset_right_stick_scroll()
	_right_stick_max_scroll = _max_future_scroll()
	_update_overflow_fade()


func _max_future_scroll() -> int:
	var bar := future_scroll.get_v_scroll_bar()
	return maxi(int(ceil(bar.max_value - bar.page)), 0)


func _update_overflow_fade(_value: float = 0.0) -> void:
	overflow_fade.visible = (
		_max_future_scroll() > 0
		and future_scroll.scroll_vertical < _max_future_scroll()
	)


func _clear_queue() -> void:
	if active_item:
		active_item.queue_free()
		active_item = null
	for item in future_items:
		item.queue_free()
	future_items.clear()
	active_actor_ref = null
	future_content.custom_minimum_size.y = 0.0
	future_scroll.scroll_vertical = 0
	_reset_right_stick_scroll()
	_right_stick_max_scroll = 0
	overflow_fade.visible = false
