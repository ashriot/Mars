extends Node2D

# --- LOAD YOUR SCENES HERE IN INSPECTOR ---
@export_group("Packed Scenes")
@export var battle_scene_packed: PackedScene
@export var terminal_scene_packed: PackedScene
# @export var event_scene_packed: PackedScene

# --- REFERENCES ---
@onready var map = $DungeonMap
@onready var overlay_layer = $OverlayLayer

func _ready():
	# Listen for when the player moves to a node
	map.interaction_requested.connect(_on_map_interaction_requested)

func _on_map_interaction_requested(node: MapNode):
	map.process_mode = Node.PROCESS_MODE_DISABLED
	var instance = null

	match node.type:
		MapNode.NodeType.COMBAT, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			instance = battle_scene_packed.instantiate()
			instance.manager.battle_ended.connect(_on_content_finished)

		#MapNode.NodeType.TERMINAL:
			#instance = terminal_scene_packed.instantiate()
			#instance.finished.connect(_on_content_finished)

		_:
			print("No scene for this node type yet.")
			_on_content_finished()
			return

	# 3. Setup and Add to Screen
	if instance:
		overlay_layer.add_child(instance)

		# Pass data to the scene if it has a setup function
		if instance.has_method("setup"):
			instance.setup(node)

func _on_content_finished():
	# 1. Unpause Map
	map.process_mode = Node.PROCESS_MODE_INHERIT

	# 2. Tell Map the node is fully done (mark visually as visited)
	map.complete_current_node()

	# 3. Cleanup (The instance usually queue_free()s itself, but we can double check)
	# If your BattleScene calls queue_free() on itself, this loop does nothing.
	# If it doesn't, this cleans it up.
	for child in overlay_layer.get_children():
		child.queue_free()
