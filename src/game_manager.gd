extends Node2D
class_name GameManager

@export_group("Packed Scenes")
@export var battle_scene_packed: PackedScene
@export var terminal_scene_packed: PackedScene
# @export var event_scene_packed: PackedScene

# --- REFERENCES ---
@onready var dungeon_map: DungeonMap = $DungeonMap
@onready var overlay_layer = $DungeonMap/OverlayLayer
@onready var fader: ColorRect = $CanvasLayer/Fader

var battle_scene: BattleScene = null


func _ready():
	fader.modulate.a = 1.0

	dungeon_map.interaction_requested.connect(_on_map_interaction_requested)
	dungeon_map.initialize_map()

	var tween = create_tween()
	tween.tween_property(fader, "modulate:a", 0.0, 1.0)\
		.set_delay(0.25)
	await tween.finished
	fader.hide()

func _on_map_interaction_requested(node: MapNode):
	dungeon_map.current_map_state = DungeonMap.MapState.LOCKED
	var instance = null

	match node.type:
		MapNode.NodeType.ENTRANCE:
			print("Escaping the dungeon!")
			_on_content_finished(false)

		MapNode.NodeType.COMBAT, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			start_encounter()

		MapNode.NodeType.TERMINAL:
			var data = dungeon_map.terminal_memory.get(node.grid_coords)
			if not data:
				push_error("No terminal data found for node: ", node.grid_coords)
				_on_content_finished(true) # Fail safe
				return

			var terminal = terminal_scene_packed.instantiate()
			overlay_layer.add_child(terminal)
			terminal.setup(data)
			terminal.option_selected.connect(_on_terminal_choice.bind(data))
			terminal.closed.connect(_on_terminal_closed)
		_:
			_on_content_finished()
			return

	# 3. Setup and Add to Screen
	if instance:
		overlay_layer.add_child(instance)

		# Pass data to the scene if it has a setup function
		if instance.has_method("setup"):
			instance.setup(node)

func _on_content_finished(should_complete_node: bool = true):
	if should_complete_node:
		await dungeon_map.complete_current_node()

	RunManager.auto_save()

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

func _on_terminal_choice(choice_tag: String, data: Dictionary):
	match choice_tag:
		# SECURITY
		"opt_sec", "opt_sec_up":
			dungeon_map.modify_alert(-int(data.alert))

		# MEDICAL
		"opt_med", "opt_med_up":
			var is_upgraded = (data.upgrade_key == "medical")
			_handle_medical_logic(is_upgraded)

		# FINANCE
		"opt_fin", "opt_fin_up":
			RunManager.add_run_bits(int(data.bits))

		"opt_extract":
			_handle_extraction()

	_on_content_finished(true)

func _handle_medical_logic(is_upgraded: bool):
	# Logic:
	# Iterate RunManager.party_roster (HeroData)
	# If Injury > 0: Remove Injury.
	# If Injury == 0: Grant "Overcharge" (Start next battle with Focus).
	# If Upgraded: Do Both (or Mega Overcharge).

	for hero_data in RunManager.party_roster:
		if hero_data.injuries > 0:
			hero_data.injuries = max(0, hero_data.injuries - 1)
			print(hero_data.hero_name, " injury removed.")

			if is_upgraded:
				# Add "Overcharge" condition to HeroData for next battle
				pass
		else:
			# Add "Overcharge" condition
			pass

func _handle_extraction():
	# 1. Transfer Run Bits to Save Bits
	SaveSystem.bits += RunManager.run_bits
	RunManager.run_bits = 0

	# 2. Save and Exit
	RunManager.is_run_active = false
	SaveSystem.save_current_slot() # Save the loot!

	# 3. Return to Title (or Hub)
	get_tree().change_scene_to_file("res://src/ui/TitleScreen.tscn")

func _on_terminal_closed():
	_on_content_finished(false)
