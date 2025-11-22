extends Node2D

@export_group("Packed Scenes")
@export var battle_scene_packed: PackedScene
@export var terminal_scene_packed: PackedScene
# @export var event_scene_packed: PackedScene

# --- REFERENCES ---
@onready var dungeon_map: DungeonMap = $DungeonMap
@onready var overlay_layer = $OverlayLayer

var battle_scene: Node = null


func _ready():
	# Listen for when the player moves to a node
	dungeon_map.interaction_requested.connect(_on_map_interaction_requested)

func _on_map_interaction_requested(node: MapNode):
	var instance = null

	match node.type:
		MapNode.NodeType.COMBAT, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			start_encounter()

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
	dungeon_map.complete_current_node()

	# 3. Cleanup (The instance usually queue_free()s itself, but we can double check)
	# If your BattleScene calls queue_free() on itself, this loop does nothing.
	# If it doesn't, this cleans it up.
	for child in overlay_layer.get_children():
		child.queue_free()

func start_encounter():
	AudioManager.play_music("battle", 0.0)
	# 1. Tell map to transition visuals
	await dungeon_map.enter_battle_visuals()

	# 3. Instantiate Battle UI on top (make sure its canvas layer is higher)
	dungeon_map.process_mode = Node.PROCESS_MODE_DISABLED
	battle_scene = battle_scene_packed.instantiate()
	overlay_layer.add_child(battle_scene)
	battle_scene.battle_ended.connect(end_encounter)

	# 4. Tell Battle UI to fade itself in
	await get_tree().create_timer(0.5).timeout
	battle_scene.fade_in()

func end_encounter():
	await battle_scene.fade_out()
	dungeon_map.process_mode = Node.PROCESS_MODE_ALWAYS
	dungeon_map.exit_battle_visuals(1.0)
	_on_content_finished()
