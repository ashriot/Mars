extends Node2D
class_name GameManager

enum InteractionOutcome { COMPLETED, CANCELED, RUN_ENDED, ERROR }

signal dungeon_exited(success: bool)
signal restore_failed

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
var current_encounter: Encounter
var _encounter_resolution_started := false
var _run_end_started := false
var _dungeon_exit_emitted := false
var _scan_outcome_handled := false

func _ready():
	var loader = loading_screen_scene.instantiate()
	overlay_layer.add_child(loader)

	# 2. Connect Map Signals
	dungeon_map.map_generation_progress.connect(loader.update_progress)
	dungeon_map.interaction_requested.connect(_on_map_interaction_requested)

	_handle_map_initialization_result(await dungeon_map.initialize_map())

func _handle_map_initialization_result(succeeded: bool) -> void:
	if succeeded:
		return
	push_error("GameManager: Dungeon map initialization failed.")
	restore_failed.emit.call_deferred()

func _on_map_interaction_requested(node: MapNode):
	dungeon_map.current_map_state = DungeonMap.MapState.LOCKED

	match node.type:
		MapNode.NodeType.ENTRANCE:
			print("Escaping the dungeon!")
			_begin_run_end(RunManager.RunResult.RETREAT)

		MapNode.NodeType.COMBAT, MapNode.NodeType.ELITE, MapNode.NodeType.BOSS:
			var enc = dungeon_map.encounter_memory.get(node.grid_coords)
			if not DungeonSaveCodec.is_valid_encounter_payload(enc):
				_report_interaction_error("Invalid encounter payload at %s: %s" % [node.grid_coords, enc])
				_finish_interaction(InteractionOutcome.ERROR)
				return
			var enc_id = enc[0]
			var is_elite = enc[1]
			var is_boss = enc[2]

			var encounter_template := EncounterDatabase.get_encounter_by_id(enc_id)
			if encounter_template == null:
				_report_interaction_error("Unknown encounter ID '%s' at %s (payload: %s)" % [enc_id, node.grid_coords, enc])
				_finish_interaction(InteractionOutcome.ERROR)
				return
			var encounter_res = encounter_template.duplicate()
			encounter_res.is_elite = is_elite
			encounter_res.is_boss = is_boss
			_start_encounter(encounter_res)

		MapNode.NodeType.REWARD, MapNode.NodeType.REWARD_2, MapNode.NodeType.REWARD_3, MapNode.NodeType.REWARD_4:
			_handle_reward_cache(node)

		MapNode.NodeType.TERMINAL:
			var data = dungeon_map.terminal_memory.get(node.grid_coords)
			if not DungeonSaveCodec.is_valid_terminal_payload(data):
				_report_interaction_error("Invalid terminal payload at %s: %s" % [node.grid_coords, data])
				_finish_interaction(InteractionOutcome.ERROR)
				return

			var terminal = terminal_scene_packed.instantiate()
			overlay_layer.add_child(terminal)
			terminal.setup(data)
			terminal.option_selected.connect(_on_terminal_choice.bind(data))
			terminal.closed.connect(_on_terminal_closed)

		MapNode.NodeType.EXIT:
			_begin_run_end(RunManager.RunResult.SUCCESS)

		_:
			_finish_interaction(InteractionOutcome.COMPLETED)
			return

func _finish_interaction(outcome: InteractionOutcome) -> void:
	if _run_end_started:
		return
	match outcome:
		InteractionOutcome.COMPLETED:
			await _complete_current_interaction()
		InteractionOutcome.CANCELED, InteractionOutcome.ERROR:
			_cancel_current_interaction()
		InteractionOutcome.RUN_ENDED:
			pass

func _clear_transient_overlay() -> void:
	for child in overlay_layer.get_children():
		overlay_layer.remove_child(child)
		child.queue_free()

func _complete_current_interaction() -> void:
	_clear_transient_overlay()
	await dungeon_map.complete_current_node()
	RunManager.auto_save()
	dungeon_map.unlock_input()

func _cancel_current_interaction() -> void:
	_clear_transient_overlay()
	dungeon_map.unlock_input()

func _report_interaction_error(message: String) -> void:
	push_error("GameManager interaction error: " + message)

func _start_encounter(encounter: Encounter):
	current_encounter = encounter
	_encounter_resolution_started = false
	AudioManager.play_sfx("radiate")
	await get_tree().create_timer(0.05).timeout

	AudioManager.play_music("battle", 0.0, true, false)
	await dungeon_map.enter_battle_visuals()

	battle_scene = battle_scene_packed.instantiate()
	overlay_layer.add_child(battle_scene)
	battle_scene.setup_battle(encounter)
	battle_scene.battle_ended.connect(end_encounter)

func end_encounter(won: bool):
	if _encounter_resolution_started:
		return
	_encounter_resolution_started = true
	var result := _result_for_battle_end(won)
	current_encounter = null

	dungeon_map.exit_battle_visuals(1.0)

	if result == -1:
		AudioManager.play_music("map_1", 1.0, false, true)
		_finish_interaction(InteractionOutcome.COMPLETED)
	else:
		_begin_run_end(result as RunManager.RunResult)
	dungeon_map.refresh_team_status()


func _result_for_battle_end(won: bool) -> int:
	if not won:
		return RunManager.RunResult.DEFEAT
	if current_encounter != null and current_encounter.is_boss:
		return RunManager.RunResult.SUCCESS
	return -1

func _on_terminal_choice(choice_tag: String, data: Dictionary):
	match choice_tag:
		"opt_scan", "opt_scan_up":
			_scan_outcome_handled = false
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
			_begin_run_end(RunManager.RunResult.RETREAT)
			return

	_finish_interaction(InteractionOutcome.COMPLETED)

func _on_scan_success():
	if _scan_outcome_handled:
		return
	_scan_outcome_handled = true
	if dungeon_map.scan_canceled.is_connected(_on_scan_canceled):
		dungeon_map.scan_canceled.disconnect(_on_scan_canceled)
	_finish_interaction(InteractionOutcome.COMPLETED)

func _on_scan_canceled():
	if _scan_outcome_handled:
		return
	_scan_outcome_handled = true
	if dungeon_map.scan_performed.is_connected(_on_scan_success):
		dungeon_map.scan_performed.disconnect(_on_scan_success)
	_on_map_interaction_requested(dungeon_map.current_node)

func _on_terminal_closed():
	_finish_interaction(InteractionOutcome.CANCELED)

func _handle_medical_logic(is_upgraded: bool):
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for hero_data in RunManager.party_roster:
		var needs_boon_roll := (hero_data.injuries > 0) == is_upgraded
		var boon_roll := rng.randf() if needs_boon_roll else 0.0
		DungeonRules.apply_medical_to_hero(hero_data, is_upgraded, boon_roll)

	dungeon_map.refresh_team_status()

func _handle_reward_cache(node: MapNode):
	var loot = dungeon_map.reward_memory.get(node.grid_coords)

	if not DungeonSaveCodec.is_valid_reward_payload(loot):
		_report_interaction_error("Invalid reward payload at %s: %s" % [node.grid_coords, loot])
		_finish_interaction(InteractionOutcome.ERROR)
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

	elif type == LootManager.LootType.MOD:
		var id = loot.id
		var tier = int(loot.get("tier", 1))
		RunManager.add_loot_mod(id, tier)
		var pretty_name = ItemDatabase.get_item_name(id)
		msg = "%s (T%d)" % [pretty_name, tier]
		icon_tex = ItemDatabase.get_item_icon(id)
		color = Color.ORANGE

	print(msg)
	var ft: FloatingText = floating_text_scene.instantiate()
	dungeon_map.add_child(ft)
	ft.setup(node.global_position, msg, icon_tex, color)

	_finish_interaction(InteractionOutcome.COMPLETED)

func _begin_run_end(result: RunManager.RunResult) -> void:
	if _run_end_started:
		return
	_run_end_started = true
	dungeon_map.current_map_state = DungeonMap.MapState.LOCKED
	_clear_transient_overlay()
	_present_end_screen(result)


func _present_end_screen(result: RunManager.RunResult) -> void:
	var screen = dungeon_end_screen_scene.instantiate()
	overlay_layer.add_child(screen)
	screen.setup(result)
	screen.finished.connect(_on_end_screen_finished, CONNECT_ONE_SHOT)


func _on_end_screen_finished() -> void:
	if _dungeon_exit_emitted:
		return
	_dungeon_exit_emitted = true
	dungeon_exited.emit(true)
