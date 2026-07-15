extends Control
class_name TurnQueue


const ITEM_SPACING := 8
const RIGHT_STICK_DEAD_ZONE := 0.25
const RIGHT_STICK_SCROLL_SPEED := 700.0

@export var actor_queue_scene: PackedScene
@export var battle_manager: BattleManager

@onready var rail_background: Panel = $RailBackground
@onready var queue_scroll: ScrollContainer = $QueueScroll
@onready var queue_content: Control = $QueueScroll/QueueContent
@onready var overflow_fade: TextureRect = $OverflowFade

var queue_items: Array[ActorQueue] = []
var _right_stick_y := 0.0
var _right_stick_scroll_residual := 0.0
var _right_stick_direction := 0
var _right_stick_max_scroll := -1
var _projection_generation := 0


func _ready() -> void:
	if is_instance_valid(battle_manager):
		battle_manager.turn_order_updated.connect(_on_turn_order_updated)
	var bar := queue_scroll.get_v_scroll_bar()
	bar.value_changed.connect(_on_scroll_changed)
	bar.custom_minimum_size.x = 6.0
	_on_scroll_changed(queue_scroll.scroll_vertical)


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
	var current_scroll := queue_scroll.scroll_vertical
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
	queue_scroll.scroll_vertical = target_scroll
	if target_scroll == 0 or target_scroll == max_scroll:
		_right_stick_scroll_residual = 0.0


func _reset_right_stick_scroll() -> void:
	_right_stick_scroll_residual = 0.0
	_right_stick_direction = 0


func _on_turn_order_updated(
	projected_queue: Array,
	update_kind: BattleManager.TurnOrderUpdate = BattleManager.TurnOrderUpdate.REFRESH,
) -> void:
	if not is_inside_tree():
		return
	_projection_generation += 1
	var generation := _projection_generation
	var resets_scroll := update_kind in [
		BattleManager.TurnOrderUpdate.COMMIT,
		BattleManager.TurnOrderUpdate.ADVANCE,
	]
	var saved_scroll := 0 if resets_scroll else queue_scroll.scroll_vertical
	if resets_scroll:
		queue_scroll.scroll_vertical = 0
	for item: ActorQueue in queue_items:
		item.queue_free()
	queue_items.clear()
	if projected_queue.is_empty():
		_clear_queue()
		return

	var occurrences: Dictionary = {}
	for index in projected_queue.size():
		var turn_data: Dictionary = projected_queue[index]
		var actor: ActorCard = turn_data.actor
		var occurrence := int(occurrences.get(actor, 0))
		occurrences[actor] = occurrence + 1
		var item := actor_queue_scene.instantiate() as ActorQueue
		queue_content.add_child(item)
		item.setup(actor, int(turn_data.ticks_needed), index == 0, occurrence, false)
		item.position = _target_position(index)
		queue_items.append(item)

	queue_content.custom_minimum_size = Vector2(
		queue_scroll.size.x - queue_scroll.get_v_scroll_bar().get_combined_minimum_size().x,
		queue_items.size() * int(ActorQueue.ITEM_SIZE.y + ITEM_SPACING) - ITEM_SPACING,
	)
	call_deferred("_restore_scroll", saved_scroll, generation)


func _target_position(index: int) -> Vector2:
	var usable_width := queue_scroll.size.x - 10.0
	return Vector2(
		(usable_width - ActorQueue.ITEM_SIZE.x) * 0.5,
		index * (ActorQueue.ITEM_SIZE.y + ITEM_SPACING),
	)


func _restore_scroll(value: int, generation: int) -> void:
	if generation != _projection_generation:
		return
	queue_scroll.scroll_vertical = clampi(value, 0, _max_future_scroll())
	_reset_right_stick_scroll()
	_right_stick_max_scroll = _max_future_scroll()
	_on_scroll_changed(queue_scroll.scroll_vertical)


func _max_future_scroll() -> int:
	var bar := queue_scroll.get_v_scroll_bar()
	return maxi(int(ceil(bar.max_value - bar.page)), 0)


func _on_scroll_changed(value: float) -> void:
	var bar := queue_scroll.get_v_scroll_bar()
	bar.modulate.a = 0.0 if is_zero_approx(value) else 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_zero_approx(value) \
		else Control.MOUSE_FILTER_STOP
	_update_overflow_fade(value)


func _update_overflow_fade(_value: float = 0.0) -> void:
	overflow_fade.visible = (
		_max_future_scroll() > 0
		and queue_scroll.scroll_vertical < _max_future_scroll()
	)


func _clear_queue() -> void:
	for item: ActorQueue in queue_items:
		item.queue_free()
	queue_items.clear()
	queue_content.custom_minimum_size.y = 0.0
	queue_scroll.scroll_vertical = 0
	_reset_right_stick_scroll()
	_right_stick_max_scroll = 0
	var bar := queue_scroll.get_v_scroll_bar()
	bar.modulate.a = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overflow_fade.visible = false
