extends Control
class_name TurnQueue

@export var actor_queue_scene: PackedScene
@export var battle_manager: BattleManager

@onready var queue := $Queue


func _ready():
	battle_manager.turn_order_updated.connect(_on_turn_order_updated)

func _on_turn_order_updated(projected_actor_list: Array):
	for child in queue.get_children():
		child.queue_free()

	for actor in projected_actor_list:
		var actor_queue = actor_queue_scene.instantiate() as ActorQueue
		actor_queue.setup(actor)
		queue.add_child(actor_queue)
