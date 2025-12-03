extends Node2D
class_name GameManager

signal dungeon_exited(success: bool)

@export_group("Packed Scenes")
@export var battle_scene_packed: PackedScene
@export var terminal_scene_packed: PackedScene
@export var loading_screen_scene: PackedScene
@export var dungeon_end_screen_scene: PackedScene
@export var floating_text_scene: PackedScene

# --- REFERENCES ---
@onready var dungeon_map: DungeonMap = $DungeonMap
@onready var overlay_layer = $DungeonMap/OverlayLayer

var battle_scene: BattleScene

func _ready():
	var loader = loading_screen_scene.instantiate()
	overlay_layer.add_child(loader)

	# 2. Connect Map Signals
	dungeon_map.map_generation_progress.connect(loader.update_progress)
	dungeon_map.interaction_requested.connect(_on_map_interaction_requested)

	dungeon_map.initialize_map()

func _on_map_interaction_requested(node: MapNode):
	dungeon_map.current_map_state = DungeonMap.MapState.LOCKED

	match node.type:
		MapNode.NodeType.ENTRANCE:
			print("Escaping the dungeon!")
			_handle_extraction()

		MapNode.NodeType.COMBAT, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:

			var enc = dungeon_map.encounter_memory.get(node.grid_coords, "")
			var enc_id = enc[0]
			var is_elite = enc[1]
			var is_boss = enc[2]

			var encounter_res = EncounterDatabase.get_encounter_by_id(enc_id).duplicate()
			encounter_res.is_elite = is_elite
			encounter_res.is_boss = is_boss

			if encounter_res:
				_start_encounter(encounter_res)
			else:
				push_error("Encounter not found for ID: " + enc_id)

		MapNode.NodeType.REWARD, MapNode.NodeType.REWARD_2, MapNode.NodeType.REWARD_3, MapNode.NodeType.REWARD_4:
			_handle_reward_cache(node)

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
	for child in overlay_layer.get_children():
		child.queue_free()

	if should_complete_node:
		await dungeon_map.complete_current_node()
		RunManager.auto_save()
	dungeon_map.unlock_input()

func _start_encounter(encounter: Encounter):
	AudioManager.play_sfx("radiate")
	await get_tree().create_timer(0.05).timeout

	AudioManager.play_music("battle", 0.0, true, false)
	await dungeon_map.enter_battle_visuals()

	battle_scene = battle_scene_packed.instantiate()
	overlay_layer.add_child(battle_scene)
	battle_scene.setup_battle(encounter)
	battle_scene.battle_ended.connect(end_encounter)

func end_encounter(won: bool):
	dungeon_map.exit_battle_visuals(1.0)

	if won:
		AudioManager.play_music("map_1", 1.0, false, true)
		_on_content_finished(true)

	else:
		_show_end_screen(RunManager.RunResult.DEFEAT)
	dungeon_map.refresh_team_status()

func _on_terminal_choice(choice_tag: String, data: Dictionary):
	match choice_tag:
		"opt_scan", "opt_scan_up":
			var radius = 2 if choice_tag == "opt_scan_up" else 1

			for child in overlay_layer.get_children():
				child.queue_free()
			dungeon_map.scan_performed.connect(_on_scan_success, CONNECT_ONE_SHOT)
			dungeon_map.scan_canceled.connect(_on_scan_canceled, CONNECT_ONE_SHOT)
			dungeon_map.start_targeting_mode(radius)
			return

		"opt_sec", "opt_sec_up":
			dungeon_map.modify_alert(-int(data.alert))

		"opt_med", "opt_med_up":
			var is_upgraded = (data.upgrade_key == "medical")
			_handle_medical_logic(is_upgraded)

		"opt_fin", "opt_fin_up":
			RunManager.add_run_bits(int(data.bits))

		"opt_extract":
			_handle_extraction()

	_on_content_finished(true)

func _on_scan_success():
	if dungeon_map.scan_canceled.is_connected(_on_scan_canceled):
		dungeon_map.scan_canceled.disconnect(_on_scan_canceled)
	_on_content_finished(true)

func _on_scan_canceled():
	if dungeon_map.scan_performed.is_connected(_on_scan_success):
		dungeon_map.scan_performed.disconnect(_on_scan_success)
	_on_map_interaction_requested(dungeon_map.current_node)

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

	dungeon_map.refresh_team_status()

func _handle_reward_cache(node: MapNode):
	var loot = dungeon_map.reward_memory.get(node.grid_coords)

	if not loot:
		push_error("No loot found for node: ", node.grid_coords)
		_on_content_finished(true)
		return

	AudioManager.play_sfx("terminal")

	var color = Color.BLACK
	if loot.has("color_html"):
		color = Color.html(loot.color_html)

	# 1. Process Loot (Give it to player)
	var type: int = loot.get("type")
	var msg = ""

	if loot.has("color_html"):
		color = Color.html(loot.color_html)

	var icon_tex: Texture2D = null

	if type == LootManager.LootType.BITS:
		# Bits are special (not in DB)
		var amount = int(loot.amount)
		RunManager.add_run_bits(amount)
		msg = "+%.1f Bits" % float(amount / 10.0)
		# icon_tex = ... (optional bits icon)

	elif type == LootManager.LootType.MATERIAL or type == LootManager.LootType.COMPONENT:
		var id = loot.id
		var amount = int(loot.amount)
		RunManager.add_loot_item(id, amount)
		var pretty_name = ItemDatabase.get_item_name(id)
		msg = "%s (x%d)" % [pretty_name, amount]
		icon_tex = ItemDatabase.get_item_icon(id)

	elif type == LootManager.LootType.EQUIPMENT:
		var id = loot.id
		RunManager.add_loot_item(id, 1)
		var pretty_name = ItemDatabase.get_item_name(id)
		msg = "%s (x%d)" % [pretty_name, 1]
		icon_tex = ItemDatabase.get_item_icon(id)

	print(msg)
	var ft: FloatingText = floating_text_scene.instantiate()
	dungeon_map.add_child(ft)
	ft.setup(node.global_position, msg, icon_tex, color)

	_on_content_finished(true)

func _handle_extraction():
	print("Extraction requested.")

	# Determine if this is a Win or a Retreat
	# If we are at the EXIT node or BOSS node, it's a Success.
	# Otherwise (Entrance/Terminal), it's a Retreat.
	var result = RunManager.RunResult.RETREAT

	if dungeon_map.current_node.type == MapNode.NodeType.EXIT or \
	   dungeon_map.current_node.type == MapNode.NodeType.BOSS:
		result = RunManager.RunResult.SUCCESS

	_show_end_screen(result)

func _on_party_wipe():
	# This comes from the BattleManager signal "dungeon_exited(false)"
	_show_end_screen(RunManager.RunResult.DEFEAT)

func _show_end_screen(result: RunManager.RunResult):
	var screen = dungeon_end_screen_scene.instantiate()
	overlay_layer.add_child(screen)
	screen.setup(result)
	await screen.finished

	dungeon_exited.emit(true)
