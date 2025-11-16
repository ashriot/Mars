# TurnQueue.gd
extends Control
class_name TurnQueue

@export var actor_queue_scene: PackedScene
@export var battle_manager: BattleManager
@onready var queue := $Queue

func _ready():
	battle_manager.turn_order_updated.connect(_on_turn_order_updated)

func _on_turn_order_updated(projected_queue: Array):
	for child in queue.get_children():
		child.queue_free()

	if projected_queue.is_empty():
		return

	var first_turn_ticks = projected_queue[0].ticks_needed

	for turn_data in projected_queue:
		var actor_queue_item = actor_queue_scene.instantiate() as ActorQueue

		var actor: ActorCard = turn_data.actor
		if projected_queue.size() > 1:
			if projected_queue[1] == turn_data:
				actor.show_next()
			else:
				actor.next_panel.hide()

		var relative_ticks = turn_data.ticks_needed - first_turn_ticks

		queue.add_child(actor_queue_item)
		actor_queue_item.setup(actor, relative_ticks)

	if projected_queue.size() > 1:
		projected_queue[1].actor.show_next()
