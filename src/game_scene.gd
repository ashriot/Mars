extends Node2D

@export_group("Packed Scenes")
@export var battle_scene_packed: PackedScene
@export var terminal_scene_packed: PackedScene
# @export var event_scene_packed: PackedScene

# --- REFERENCES ---
@onready var dungeon_map: DungeonMap = $DungeonMap
@onready var overlay_layer = $DungeonMap/OverlayLayer

var battle_scene: Node = null


func _ready():
	# Listen for when the player moves to a node
	dungeon_map.interaction_requested.connect(_on_map_interaction_requested)

func _on_map_interaction_requested(node: MapNode):
	dungeon_map.current_map_state = DungeonMap.MapState.LOCKED
	var instance = null

	match node.type:
		MapNode.NodeType.COMBAT, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			start_encounter()

		MapNode.NodeType.TERMINAL:
			var terminal = terminal_scene_packed.instantiate() as Control
			overlay_layer.add_child(terminal)
			terminal.setup("ALPHA FACILITY", 50, 25)
			terminal.option_selected.connect(_on_terminal_choice)
			terminal.closed.connect(_on_terminal_closed)

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

# Default is true so existing calls (like battles) default to completing
func _on_content_finished(should_complete_node: bool = true):
	if should_complete_node:
		await dungeon_map.complete_current_node()

	for child in overlay_layer.get_children():
		child.queue_free()

	dungeon_map.current_map_state = DungeonMap.MapState.PLAYING

func start_encounter():
	AudioManager.play_sfx("radiate")
	await get_tree().create_timer(0.25).timeout
	AudioManager.play_music("battle", 0.0, true, false)
	# 1. Tell map to transition visuals
	await dungeon_map.enter_battle_visuals()

	# 3. Instantiate Battle UI on top (make sure its canvas layer is higher)
	battle_scene = battle_scene_packed.instantiate()
	overlay_layer.add_child(battle_scene)
	battle_scene.battle_ended.connect(end_encounter)

	# 4. Tell Battle UI to fade itself in
	await get_tree().create_timer(0.5).timeout
	battle_scene.fade_in()

func end_encounter():
	await battle_scene.fade_out()
	dungeon_map.exit_battle_visuals(1.0)
	AudioManager.play_music("map_1", 1.0, false, true)
	_on_content_finished()

func _on_terminal_choice(opt: int):
	AudioManager.play_sfx("terminal")
	if opt == 1:
		print("Gained Bits")
	elif opt == 2:
		dungeon_map.modify_alert(-25)
	_on_content_finished(true)

func _on_terminal_closed():
	_on_content_finished(false)
