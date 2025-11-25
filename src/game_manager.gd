extends Node2D
class_name GameManager

signal dungeon_exited(success: bool)

@export_group("Packed Scenes")
@export var battle_scene_packed: PackedScene
@export var terminal_scene_packed: PackedScene
@export var loading_screen_scene: PackedScene

# --- REFERENCES ---
@onready var dungeon_map: DungeonMap = $DungeonMap
@onready var overlay_layer = $DungeonMap/OverlayLayer
@onready var fader: ColorRect = $CanvasLayer/Fader

var battle_scene: BattleScene = null

func _ready():
	# 1. Setup Loading Screen
	# We instantiate this IMMEDIATELY.
	# Since Main.gd is currently fading in from black, this will be
	# the first thing the player sees when the lights come on.
	var loader = loading_screen_scene.instantiate()
	overlay_layer.add_child(loader)

	# 2. Connect Map Signals
	dungeon_map.map_generation_progress.connect(loader.update_progress)
	dungeon_map.interaction_requested.connect(_on_map_interaction_requested)

	# 3. Initialize Map
	# We do NOT need to 'await' this. We let it run in the background.
	# The Loading Screen will handle the UI feedback.
	dungeon_map.initialize_map()

	# (Removed all Fader tweening logic. Main.gd handles the transition.)

func _on_map_interaction_requested(node: MapNode):
	dungeon_map.current_map_state = DungeonMap.MapState.LOCKED

	match node.type:
		MapNode.NodeType.ENTRANCE:
			print("Escaping the dungeon!")
			_handle_extraction() # Use the helper function

		MapNode.NodeType.COMBAT, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			start_encounter()

		MapNode.NodeType.TERMINAL:
			var data = dungeon_map.terminal_memory.get(node.grid_coords)
			if not data:
				push_error("No terminal data found for node: ", node.grid_coords)
				_on_content_finished(true)
				return

			var terminal = terminal_scene_packed.instantiate()
			overlay_layer.add_child(terminal)
			terminal.setup(data)
			terminal.option_selected.connect(_on_terminal_choice.bind(data))
			terminal.closed.connect(_on_terminal_closed)

		MapNode.NodeType.EXIT:
			_handle_extraction()

		_:
			_on_content_finished()
			return

func _on_content_finished(should_complete_node: bool = true):
	if should_complete_node:
		await dungeon_map.complete_current_node()
		# Auto-save progress after resolving an event
		RunManager.auto_save()

	# Clear UI
	for child in overlay_layer.get_children():
		child.queue_free()

	dungeon_map.current_map_state = DungeonMap.MapState.PLAYING

# --- COMBAT HANDLING ---

func start_encounter():
	AudioManager.play_sfx("radiate")
	# Small pause for impact
	await get_tree().create_timer(0.25).timeout

	AudioManager.play_music("battle", 0.0, true, false)
	await dungeon_map.enter_battle_visuals()

	battle_scene = battle_scene_packed.instantiate()
	overlay_layer.add_child(battle_scene)
	battle_scene.battle_ended.connect(end_encounter)

	# (If you have a death signal in battle_scene, connect it to _on_party_wipe)
	# battle_scene.party_wiped.connect(_on_party_wipe)

	await get_tree().create_timer(0.5).timeout
	battle_scene.fade_in()

func end_encounter():
	await battle_scene.fade_out()
	dungeon_map.exit_battle_visuals(1.0)
	AudioManager.play_music("map_1", 1.0, false, true)
	_on_content_finished(true)

# --- TERMINAL LOGIC ---

func _on_terminal_choice(choice_tag: String, data: Dictionary):
	match choice_tag:
		"opt_sec", "opt_sec_up":
			dungeon_map.modify_alert(-int(data.alert))

		"opt_med", "opt_med_up":
			# Pass 'true' if it is the Upgraded Key
			var is_upgraded = (data.upgrade_key == "medical")
			_handle_medical_logic(is_upgraded)

		"opt_fin", "opt_fin_up":
			RunManager.add_run_bits(int(data.bits))

		"opt_extract":
			_handle_extraction()

	_on_content_finished(true)

func _on_terminal_closed():
	_on_content_finished(false)

func _handle_medical_logic(is_upgraded: bool):
	# (Your existing medical logic is perfect, keep it here)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for hero_data in RunManager.party_roster:
		if hero_data.injuries > 0:
			hero_data.injuries = 0
			if is_upgraded:
				if rng.randf() > 0.5: hero_data.boon_focused = true
				else: hero_data.boon_armored = true
		else:
			if is_upgraded:
				hero_data.boon_focused = true
				hero_data.boon_armored = true
			else:
				if rng.randf() > 0.5: hero_data.boon_focused = true
				else: hero_data.boon_armored = true

	# Refresh the Map UI (Hero Status Bars)
	get_tree().call_group("hero_status_ui", "refresh_view")

# --- END OF RUN LOGIC ---

func _handle_extraction():
	print("Extraction requested. Signaling Main...")
	dungeon_exited.emit(true)

func _on_party_wipe():
	print("Party wiped. Signaling Main...")
	dungeon_exited.emit(false)
