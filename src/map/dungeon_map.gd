extends Node2D
class_name DungeonMap

signal interaction_requested(node: MapNode)
signal map_generation_progress(current, total)

enum MapState { LOADING, PLAYING, LOCKED, TARGETING }

const ALERT_LOW_THRESHOLD = 26
const ALERT_MED_THRESHOLD = 75

# Base Costs
const COST_MOVE_BASE = 2.0
const PENALTY_NORMAL_MOVE = 2.0
const PENALTY_ELITE_MOVE = 4.0
const PENALTY_BOSS_MOVE = 2.0

@onready var camera: Camera2D = $Camera2D
@onready var hud: Control = $CanvasLayer/HUD
@onready var alert_gauge: ProgressBar = $CanvasLayer/HUD/AlertGauge
@onready var alert_label: Label = $CanvasLayer/HUD/AlertGauge/Panel2/Value
@onready var parallax_bg: Parallax2D = $Parallax2D
@onready var bg_sprite: Sprite2D = $Parallax2D/Sprite2D
@onready var background: Control = $Background
@onready var player_cursor: Sprite2D = $Background/PlayerCursor

@onready var team_status: VBoxContainer = $CanvasLayer/HUD/TeamStatus/VBox
@onready var nodes_done_label: Label = $CanvasLayer/HUD/NodeGauge/Nodes
@onready var total_nodes_label: Label = $CanvasLayer/HUD/NodeGauge/Panel/Total
@onready var warning_label: Label = $CanvasLayer/HUD/Warning

# --- Configuration ---
@export_group("Map Dimensions")
@export var map_length: int = 20
@export var map_height: int = 15

# --- Game Rules ---
@export_group("Map Rules")
@export var vision_range: int = 1

# --- Node Distribution Settings ---
@export_group("Node Counts")
@export var dungeon_has_boss: bool = false
@export var num_combats: int = 7
@export var num_elites: int = 2
@export var num_events: int = 2
@export var num_terminals: int = 4
@export var num_rewards: int = 3
@export var num_uncommon_rewards: int = 2
@export var num_rare_rewards: int = 1

# --- Camera Settings ---
@export_group("Camera")
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.5
@export var camera_smooth_speed: float = 0.3
@export var camera_edge_margin: float = 850.0

# --- Visuals ---
@export_group("Visuals")
@export var hero_status_scene: PackedScene
@export var map_node_scene: PackedScene
@export var selection_texture: Texture2D
@export var background_texture: Texture2D
@export_range(0.0, 5.0) var background_blur: float = 3.0

# --- Internal Data ---
var map_size: int
var hex_width: float
var hex_height: float
var total_nodes: int
var grid_nodes = {}
var _map_center_pos: Vector2 = Vector2.ZERO
var _pre_battle_zoom: Vector2 = Vector2.ONE
var _pre_battle_camera_pos: Vector2 = Vector2.ZERO
var _calculated_depth_scale: Vector2 = Vector2.ONE
var terminal_memory: Dictionary = {}
var alert_tween: Tween
var warning_tween: Tween

# --- Hex Values ---
var hex_size: float = 50.0
var gap: float = 40.0

# --- Dungeon Stats ---
var total_moves: int = 0
var nodes_done: int = 0
var current_node: MapNode = null
var current_alert: float = 0.0
var current_move_cost: float = 0.0
var pending_scan_radius: int = 0

# --- Player Cursor ---
var cursor_pulse_tween: Tween
var cursor_move_tween: Tween

var current_map_state: MapState = MapState.LOADING


func _ready():
	RunManager.active_dungeon_map = self
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0
	_setup_camera()

	# Visual defaults
	alert_gauge.modulate = Color.MEDIUM_SEA_GREEN
	alert_gauge.value = 0
	alert_label.text = "0%"
	hud.modulate.a = 0.0
	for hero_data in RunManager.party_roster:
		var status_ui = hero_status_scene.instantiate()
		team_status.add_child(status_ui)
		status_ui.setup(hero_data)
	_start_cursor_pulse()

func _start_cursor_pulse():
	if cursor_pulse_tween: cursor_pulse_tween.kill()

	cursor_pulse_tween = create_tween()
	cursor_pulse_tween.set_loops()
	cursor_pulse_tween.set_trans(Tween.TRANS_SINE)
	cursor_pulse_tween.set_ease(Tween.EASE_IN_OUT)

	player_cursor.modulate.a = 0.2
	cursor_pulse_tween.tween_property(player_cursor, "modulate:a", 1.0, 0.6)
	cursor_pulse_tween.tween_property(player_cursor, "modulate:a", 0.2, 0.6)

func initialize_map():
	if RunManager.is_run_active:
		print("Resuming active run...")
		await RunManager.restore_run()

		AudioManager.play_music("map_1", 1.0, false, true)
		hud.modulate.a = 1.0

		player_cursor.visible = true
		current_map_state = MapState.PLAYING

		if current_node and current_node.state != MapNode.NodeState.COMPLETED:
			print("Resuming interrupted event at ", current_node.grid_coords)
			interaction_requested.emit(current_node)

	else:
		print("Starting fresh run...")
		randomize()
		RunManager.current_run_seed = randi()
		seed(RunManager.current_run_seed)
		var map_data = await generate_hex_grid()
		current_node = map_data.start_node
		total_nodes = num_combats + num_elites + num_events + \
			num_uncommon_rewards + num_rare_rewards + num_rewards + num_terminals

		RunManager.is_run_active = true
		RunManager.auto_save()

		AudioManager.play_music("map_1", 1.0, false, false)
		await play_intro_sequence(map_data)
		AudioManager.play_sfx("radiate")

		var tween = create_tween()
		tween.tween_property(hud, "modulate:a", 1.0, 0.15)

		current_map_state = MapState.PLAYING
		print("Map ready.")
	refresh_team_status()

func load_from_save_data(data: Dictionary):
	await generate_hex_grid()

	# 2. RESTORE GLOBAL STATE
	current_alert = data.current_alert

	# 3. RESTORE NODE STATES
	for key_str in data.node_data.keys():
		var coords = str_to_var(key_str)
		var saved_info = data.node_data[key_str]

		if grid_nodes.has(coords):
			var node = grid_nodes[coords]

			# Restore logical state
			node.has_been_visited = saved_info.visited
			node.is_aware = saved_info.aware
			node.set_state(int(saved_info.state))

			node.modulate.a = 1.0

	# 4. RESTORE TERMINALS
	terminal_memory.clear()
	for key_str in data.terminal_memory.keys():
		var coords = str_to_var(key_str)
		terminal_memory[coords] = data.terminal_memory[key_str]

	total_nodes = data.total_nodes
	nodes_done = data.nodes_done

	# 5. PLACE PLAYER & CAMERA
	var player_coords = str_to_var(data.current_coords)
	if grid_nodes.has(player_coords):
		var target_node = grid_nodes[player_coords]

		# Set logic tracking
		current_node = target_node

		player_cursor.position = target_node.position
		camera.position = target_node.position
		camera.zoom = Vector2.ONE

		# Restore Parallax Depth
		if parallax_bg:
			parallax_bg.scroll_scale = _calculated_depth_scale

		# Reveal neighbors
		await _update_vision()
	_update_alert_visuals()

func _setup_camera():
	camera.make_current()

func _input(event):
	if current_map_state == MapState.LOADING or current_map_state == MapState.LOCKED: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-zoom_step)

func _generate_static_terminal_data(coords: Vector2i, index: int):
	var scalar = RunManager.get_loot_scalar()
	var session = "0x%X-%X-%X" % [randi() % 0xFFFF, \
	randi() % 0xFFFF, randi() % 0xFFFF]

	# 1. DEFINE BASE VALUES
	var bits_val = int(50 * scalar)
	var alert_val = 50 # Standard reduction
	var upgrade_key = "" # "security", "scan", "medical", "finance"

	# 2. APPLY ROTATION LOGIC
	var rot = index % 4

	if rot == 0:
		upgrade_key = "security"
		alert_val = 75

	elif rot == 1:
		upgrade_key = "scan"

	elif rot == 2:
		upgrade_key = "medical"

	elif rot == 3:
		upgrade_key = "finance"
		bits_val = int(bits_val * 2)
		bits_val = roundi(bits_val * randf_range(0.8, 1.2))

	terminal_memory[coords] = {
		"facility_name": "ALPHA NODE " + str(index + 1),
		"session_id": session,
		"terminal_index": index,
		"bits": bits_val,
		"alert": alert_val,
		"upgrade_key": upgrade_key
	}

func _zoom_camera(step: float):
	if not camera: return
	var target_zoom = camera.zoom + Vector2(step, step)
	target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
	target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)
	camera.zoom = target_zoom

func generate_hex_grid() -> Dictionary:
	print("Generating Map Logic...")

	# --- Cleanup ---
	total_moves = 0
	total_nodes = 0
	nodes_done = 0
	current_node = null
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0
	terminal_memory.clear()

	map_generation_progress.emit(0, 100)
	await get_tree().process_frame

	for child in background.get_children():
		if child.name == "PlayerCursor":
			continue
		child.queue_free()
	grid_nodes.clear()
	alert_gauge.value = 0

	# --- Grid Math ---
	map_size = map_height * map_length
	num_terminals = int(map_size / 50) + 1
	print("Terminals: ", num_terminals)
	var valid_coords = {}
	var start_pos = Vector2(100, 200)
	var center_y = floor(map_height / 2.0)
	var visual_center_x = (map_length - 1) / 2.0 + \
		(0.5 if int(center_y) % 2 == 0 else 0.0)
	var min_bounds = Vector2(INF, INF)
	var max_bounds = Vector2(-INF, -INF)

	for y in range(map_height):
		var dist_y = abs(y - center_y)
		var x_count = map_length - dist_y
		if x_count <= 0: continue

		var current_shift = 0.5 if (y % 2 == 0) else 0.0
		var x_start = round(visual_center_x - current_shift - ((x_count - 1) / 2.0))

		for i in range(x_count):
			var x = x_start + i
			var grid_pos = Vector2i(x, y)

			var x_pos = x * (hex_width + gap)
			var y_pos = y * (hex_height * 0.67 + gap)
			if y % 2 == 0: x_pos += (hex_width + gap) / 2.0

			var final_pos = start_pos + Vector2(x_pos, y_pos)
			valid_coords[grid_pos] = final_pos

			min_bounds = min_bounds.min(final_pos)
			max_bounds = max_bounds.max(final_pos)

	# --- Node Instantiation ---
	var node_types = await _distribute_node_types(valid_coords.keys(), center_y)
	var nodes_list: Array[MapNode] = []

	# --- TERMINAL GENERATION ---
	var sorted_coords = node_types.keys()
	sorted_coords.sort_custom(func(a, b):
		if a.x != b.x: return a.x < b.x
		return a.y < b.y
	)
	var terminal_counter = 0
	for coords in sorted_coords:
		if node_types[coords] == MapNode.NodeType.TERMINAL:
			_generate_static_terminal_data(coords, terminal_counter)
			terminal_counter += 1

	for coords in valid_coords.keys():
		var new_node = _create_map_node(coords.x, coords.y, valid_coords[coords], node_types[coords])
		nodes_list.append(new_node)

	_update_background_transform(min_bounds, max_bounds)

	# --- Find Start Node ---
	var center_start_x = round(visual_center_x - (0.5 if int(center_y) % 2 == 0 else 0.0) - (map_length - 1) / 2.0)
	var start_coords = Vector2i(center_start_x, center_y)
	var start_node = grid_nodes.get(start_coords, grid_nodes.values()[0] if not grid_nodes.is_empty() else null)

	map_generation_progress.emit(100, 100)

	return {
		"start_node": start_node,
		"nodes": nodes_list,
		"min_bounds": min_bounds,
		"max_bounds": max_bounds
	}

func play_intro_sequence(map_data: Dictionary) -> void:
	var start_node: MapNode = map_data.start_node
	var nodes_to_animate = map_data.nodes

	if not camera: return

	# --- 1. SETUP "WIDE SHOT" CAMERA ---
	var grid_center = (map_data.min_bounds + map_data.max_bounds) / 2.0
	camera.position = grid_center

	# Disable parallax depth so the image centers perfectly
	parallax_bg.scroll_scale = Vector2.ONE

	# Calculate Wide Zoom
	var vp_size = get_viewport_rect().size
	# Note: Ensure bg_sprite is accessible here. If it's local to generate,
	# you might need to store it or get it from 'self'.
	var bg_current_size = bg_sprite.texture.get_size() * bg_sprite.scale
	var wide_zoom = max(vp_size.x / bg_current_size.x, vp_size.y / bg_current_size.y)
	camera.zoom = Vector2(wide_zoom, wide_zoom)

	# --- 2. ANIMATE "WAVE" REVEAL ---

	# Reveal Start Node immediately
	# --- FIX 1: Safety Check ---
	if start_node:
		var start_tween = create_tween()
		start_tween.tween_property(start_node, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
		await start_tween.finished
		AudioManager.play_sfx("terminal") # Nice touch!

	# Sort remaining nodes Left-to-Right
	nodes_to_animate.sort_custom(func(a, b):
		if a.grid_coords.x != b.grid_coords.x: return a.grid_coords.x < b.grid_coords.x
		return a.grid_coords.y < b.grid_coords.y
	)

	# Run Wave
	var wave_tween = create_tween().set_parallel(true)
	var current_col_x = -9999
	var delay_timer = 0.0

	for node in nodes_to_animate:
		if node == start_node: continue

		if node.grid_coords.x != current_col_x:
			current_col_x = node.grid_coords.x
			delay_timer += 0.05

		wave_tween.tween_property(node, "modulate:a", 1.0, 0.3)\
			.set_delay(delay_timer)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

	await wave_tween.finished

	# --- 3. ZOOM IN TO PLAYER ---
	if start_node:
		var cam_tween = create_tween().set_parallel(true)
		cam_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		cam_tween.tween_property(camera, "position", start_node.position, 1.5)
		cam_tween.tween_property(camera, "zoom", Vector2.ONE, 1.5)

		cam_tween.tween_property(parallax_bg, "scroll_scale", _calculated_depth_scale, 1.5)

		var shader: ShaderMaterial = bg_sprite.material

		cam_tween.tween_method(
			func(val): shader.set_shader_parameter("blur_amount", val),
			0.0,
			background_blur,
			0.5
		)

		await cam_tween.finished

		# Hand over control
		_move_player_to(start_node, true)

func refresh_team_status():
	for hero_status in team_status.get_children():
		hero_status.refresh_view()
	nodes_done_label.text = str(nodes_done)
	total_nodes_label.text = str(total_nodes)

func _start_warning_pulse(color: Color):
	if warning_tween: warning_tween.kill()

	if current_alert < ALERT_LOW_THRESHOLD:
		warning_label.modulate = color
		return

	warning_tween = create_tween()
	warning_tween.set_loops()
	warning_tween.tween_property(
		warning_label,
		"modulate",
		color,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	warning_tween.tween_property(
		warning_label,
		"modulate",
		Color.WHITE,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func complete_current_node():
	if current_node:
		current_node.set_state(MapNode.NodeState.COMPLETED)
		await _update_vision()
		if current_node.type != MapNode.NodeType.UNKNOWN:
			nodes_done += 1
		match current_node.type:
			MapNode.NodeType.COMBAT:
				await get_tree().create_timer(1.0).timeout
				modify_alert(-10.0)
				print("Enemy Defeated: Alert -10%")
			MapNode.NodeType.ELITE:
				await get_tree().create_timer(1.0).timeout
				modify_alert(-20.0)
				print("Elite Defeated: Alert -20%")

func enter_battle_visuals(duration: float = 1.5):
	# 1. Save state
	_pre_battle_zoom = camera.zoom
	_pre_battle_camera_pos = camera.position

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# 2. Fade Elements
	tween.tween_property(background, "modulate:a", 0.0, duration / 2)
	tween.tween_property(hud, "modulate:a", 0.0, duration / 2)

	# 3. Move Camera to Center
	tween.tween_property(camera, "position", _map_center_pos, duration)
	tween.tween_property(parallax_bg, "scroll_scale", Vector2.ONE, duration)

	# 5. Calculate Zoom
	var vp_size = get_viewport_rect().size

	# Note: We use the raw texture size * sprite scale.
	# At scroll_scale 1.0, this is the exact world size we need to cover.
	var bg_current_size = bg_sprite.texture.get_size() * bg_sprite.scale

	var x_ratio = vp_size.x / bg_current_size.x
	var y_ratio = vp_size.y / bg_current_size.y

	# Use max() for "Cover" mode (fill screen, clip edges)
	var target_zoom_val = max(x_ratio, y_ratio)

	# Optional: Add a tiny padding (e.g. 1.05) to ensure no single-pixel gaps
	target_zoom_val *= 1.02

	var battle_zoom_vec = Vector2(target_zoom_val, target_zoom_val)
	tween.tween_property(camera, "zoom", battle_zoom_vec, duration)

	# 6. Clear Blur
	tween.tween_method(
		func(val): (bg_sprite.material as ShaderMaterial).set_shader_parameter("blur_amount", val),
		background_blur,
		0.0,
		duration
	)

	await tween.finished

func battle_ended():
	exit_battle_visuals()

func exit_battle_visuals(duration: float = 1.0):
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# 1. Fade IN Map Elements
	tween.tween_property(background, "modulate:a", 1.0, duration)

	# 2. Fade IN Map HUD
	tween.tween_property(hud, "modulate:a", 1.0, duration)

	# 3. Restore Camera Position
	# (If the player moved during battle, we might want to re-calculate this
	# based on 'current_node.position' instead of the saved position, just to be safe)
	var target_pos = current_node.position if current_node else _pre_battle_camera_pos
	tween.tween_property(camera, "position", target_pos, duration)

	# 4. Restore Camera Zoom
	tween.tween_property(camera, "zoom", _pre_battle_zoom, duration)

	# 5. (Optional) Restore Blur
	tween.tween_method(
		func(val): (bg_sprite.material as ShaderMaterial).set_shader_parameter("blur_amount", val),
		0.0,
		background_blur,
		duration
	)

func _update_background_transform(min_b: Vector2, max_b: Vector2):
	bg_sprite.texture = background_texture

	var padding = Vector2(hex_width * 4, hex_height * 4)
	var grid_center = (min_b + max_b) / 2.0
	_map_center_pos = grid_center
	var grid_size = (max_b - min_b) + padding

	var max_dimension = max(grid_size.x, grid_size.y)
	var depth_factor = clamp(1.0 - (max_dimension / 5000.0), 0.1, 0.9)

	_calculated_depth_scale = Vector2(depth_factor, depth_factor)
	parallax_bg.scroll_scale = _calculated_depth_scale

	var tex_size = background_texture.get_size()
	var required_scale = Vector2.ONE
	var world_coverage = grid_size * (1.0 + (1.0 - depth_factor))

	required_scale.x = world_coverage.x / tex_size.x
	required_scale.y = world_coverage.y / tex_size.y

	var final_scale = max(required_scale.x, required_scale.y)
	bg_sprite.scale = Vector2(final_scale, final_scale)
	parallax_bg.scroll_offset = grid_center

func _create_map_node(grid_x, grid_y, screen_pos, type) -> MapNode:
	var node = map_node_scene.instantiate()
	node.position = screen_pos
	node.name = "Hex_%d_%d" % [grid_x, grid_y]
	node.modulate.a = 0.0

	$Background.add_child(node)
	node.setup(Vector2i(grid_x, grid_y), type)

	node.node_clicked.connect(_on_node_clicked)
	grid_nodes[Vector2i(grid_x, grid_y)] = node

	return node

func start_targeting_mode(radius: int):
	current_map_state = MapState.TARGETING
	pending_scan_radius = radius
	print("Select a sector to scan...")

func unlock_input():
	if current_map_state == MapState.TARGETING:
		return
	current_map_state = MapState.PLAYING

func _on_node_clicked(target_node: MapNode):
	if target_node == current_node: return
	if current_map_state == MapState.TARGETING:
		execute_camera_scan(target_node, pending_scan_radius)
		current_map_state = MapState.PLAYING
		pending_scan_radius = 0
		RunManager.auto_save()
		return

	if current_map_state != MapState.PLAYING: return

	var dist = _get_hex_distance(current_node.grid_coords, target_node.grid_coords)
	if dist > 1:
		print("Too far! Dist: ", dist)
		return
	_move_player_to(target_node)

func _move_player_to(target_node: MapNode, is_start: bool = false):
	current_node = target_node
	_move_camera_to_player(is_start)
	player_cursor.visible = true

	if is_start:
		player_cursor.position = target_node.position
		target_node.has_been_visited = true
		#target_node.is_aware = true
		await _update_vision()
		_update_alert_visuals()
		return

	total_moves += 1
	var is_revisit = target_node.has_been_visited
	target_node.has_been_visited = true
	var alert_gain = current_move_cost / (2.0 if is_revisit else 1.0)
	_update_vision()
	modify_alert(alert_gain)

	RunManager.auto_save()
	await _animate_cursor_slide(target_node.position)

	if target_node.state != MapNode.NodeState.COMPLETED:
		interaction_requested.emit(target_node)

func _animate_cursor_slide(target_pos: Vector2):
	if cursor_move_tween: cursor_move_tween.kill()

	cursor_move_tween = create_tween()
	cursor_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	cursor_move_tween.tween_property(player_cursor, "position", target_pos, 0.3)
	await cursor_move_tween.finished

func _calculate_alert_gain():
	var total_cost = COST_MOVE_BASE
	var threat_penalty = 0.0
	for node in grid_nodes.values():
		if node.state == MapNode.NodeState.REVEALED and node.is_aware:
			match node.type:
				MapNode.NodeType.COMBAT:
					threat_penalty += PENALTY_NORMAL_MOVE
				MapNode.NodeType.ELITE:
					threat_penalty += PENALTY_ELITE_MOVE
				MapNode.NodeType.BOSS:
					threat_penalty += PENALTY_BOSS_MOVE
	current_move_cost = total_cost + threat_penalty

func modify_alert(amount: float):
	current_alert = clamp(current_alert + amount, 0.0, 100.0)
	_update_alert_visuals()

func _update_alert_visuals():
	_calculate_alert_gain()
	var cost_text = str(int(current_move_cost)) + "%"
	var target_color: Color
	if current_alert < ALERT_LOW_THRESHOLD:
		warning_label.text = "OK +" + cost_text
		target_color = Color(0.419, 1.063, 0.419)
		vision_range = 2
	elif current_alert < ALERT_MED_THRESHOLD:
		warning_label.text = "CAUTION +" + cost_text
		target_color = Color(1.437, 1.226, 0.0, 1.0)
		vision_range = 1
	else:
		if current_alert == 100:
			warning_label.text = "DANGER!! +" + cost_text
		else:
			warning_label.text = "WARNING! +" + cost_text
		target_color = Color(1.437, 0.234, 0.0, 1.0)
		vision_range = 0

	_start_warning_pulse(target_color)

	# 2. Setup the Tween
	if alert_tween and alert_tween.is_running():
		alert_tween.kill()

	alert_tween = create_tween().set_parallel(true)
	alert_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var duration = 0.5 # Tweak this for speed

	# 3. Animate the Value (Bar + Text)
	# We tween a method so we can update both the bar and label in sync
	alert_tween.tween_method(
		_set_alert_display_value, # The function to call
		alert_gauge.value,        # Start value (current visual state)
		float(current_alert),     # End value (target state)
		duration
	)

	# 4. Animate the Color
	alert_tween.tween_property(alert_gauge, "modulate", target_color, duration)

func _set_alert_display_value(val: float):
	alert_gauge.value = val
	alert_label.text = str(roundi(val)) + "%"

func _move_camera_to_player(force_center: bool):
	if not camera: return
	var target_pos = current_node.position

	if force_center:
		camera.position = target_pos
		return

	var vp_size = get_viewport_rect().size / camera.zoom
	var half_vp = vp_size / 2.0
	var deadzone_x = max(0.0, half_vp.x - camera_edge_margin)
	var deadzone_y = max(0.0, half_vp.y - camera_edge_margin * 0.56)
	var diff = target_pos - camera.position
	var desired_shift = Vector2.ZERO

	if diff.x > deadzone_x: desired_shift.x = diff.x - deadzone_x
	elif diff.x < -deadzone_x: desired_shift.x = diff.x + deadzone_x
	if diff.y > deadzone_y: desired_shift.y = diff.y - deadzone_y
	elif diff.y < -deadzone_y: desired_shift.y = diff.y + deadzone_y

	if desired_shift != Vector2.ZERO:
		var new_cam_pos = camera.position + desired_shift
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(camera, "position", new_cam_pos, camera_smooth_speed)

func execute_camera_scan(center_node: MapNode, radius: int):
	AudioManager.play_sfx("radiate")
	var nodes_to_reveal = []
	for node in grid_nodes.values():
		var dist = _get_hex_distance(center_node.grid_coords, node.grid_coords)

		if dist <= radius:
			if node.state == MapNode.NodeState.HIDDEN:
				node.is_aware = false
				nodes_to_reveal.append(node)

	if not nodes_to_reveal.is_empty():
		var tween = create_tween().set_parallel(true)
		for node in nodes_to_reveal:
			node.set_state(MapNode.NodeState.REVEALED)
			node.modulate.a = 0.0
			var delay = _get_hex_distance(center_node.grid_coords, node.grid_coords) * 0.1
			tween.tween_property(node, "modulate:a", 1.0, 0.5).set_delay(delay)

func _update_vision():
	if vision_range <= 0: return
	var center_coords = current_node.grid_coords
	var nodes_to_reveal: Array[MapNode] = []

	for node in grid_nodes.values():
		if node.is_aware: continue

		var dist = _get_hex_distance(center_coords, node.grid_coords)
		if dist <= vision_range:
			node.is_aware = true
			nodes_to_reveal.append(node)

	if nodes_to_reveal.is_empty():
		return

	var tween = create_tween().set_parallel(true)
	for node in nodes_to_reveal:
		node.set_state(MapNode.NodeState.REVEALED)
		node.modulate.a = 0.5
		var dist = _get_hex_distance(center_coords, node.grid_coords)
		var delay = max(0, (dist - 1) * 0.1)
		tween.tween_property(node, "modulate:a", 1.0, 0.5)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	await tween.finished

func _get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac = _offset_to_cube(a)
	var bc = _offset_to_cube(b)
	return max(abs(ac.x - bc.x), abs(ac.y - bc.y), abs(ac.z - bc.z))

func _offset_to_cube(hex: Vector2i) -> Vector3i:
	var q = hex.x - (hex.y + (hex.y & 1)) / 2
	var r = hex.y
	var s = -q - r
	return Vector3i(q, r, s)

func _distribute_node_types(all_coords: Array, center_y: int) -> Dictionary:
	var type_map = {}
	for c in all_coords: type_map[c] = MapNode.NodeType.UNKNOWN
	var available_pool = all_coords.duplicate()

	# --- 1. FIND START (ENTRANCE) ---
	var min_x = 9999
	for c in all_coords:
		if c.y == center_y and c.x < min_x: min_x = c.x
	var start_node = Vector2i(min_x, center_y)

	# Explicitly assign ENTRANCE type
	type_map[start_node] = MapNode.NodeType.ENTRANCE
	available_pool.erase(start_node)

	# --- 2. FIND END (BOSS or EXIT) ---
	var sorted_by_x = all_coords.duplicate()
	sorted_by_x.sort_custom(func(a, b): return a.x > b.x)
	var end_variance = int(map_size / 4)
	var end_candidates = sorted_by_x.slice(0, min(end_variance, sorted_by_x.size()))
	var end_node = end_candidates.pick_random()

	# Sanity check
	while end_node == start_node and end_candidates.size() > 1:
		end_node = end_candidates.pick_random()

	# Assign based on config
	if dungeon_has_boss:
		type_map[end_node] = MapNode.NodeType.BOSS
	else:
		type_map[end_node] = MapNode.NodeType.EXIT

	available_pool.erase(end_node)

	# --- 3. DEFINE "SAFE ZONE" ---
	# Remove nodes too close to start from the pool for "Good Stuff"
	# (We will add them back later for "Combat" or "Empty")
	var high_value_pool = []
	var start_buffer_zone = []

	for c in available_pool:
		if _get_hex_distance(start_node, c) <= 2: # Increased buffer to 2
			start_buffer_zone.append(c)
		else:
			high_value_pool.append(c)

	# --- SETUP PROGRESS TRACKING ---
	var total_heavy_items = num_terminals + num_elites
	var items_placed_count = 0

	# Time Budget
	var max_frame_time_ms = 8
	var frame_start_time = Time.get_ticks_msec()

	# --- 4. DISTRIBUTE TERMINALS (Spaced Out) ---
	var placed_terminals = []
	# Calculate spacing dynamically based on map size.
	var terminal_spacing = max(3, int(map_length / 3.0))

	for i in range(num_terminals):
		if high_value_pool.is_empty(): break

		var coord = _pick_distant_coord(high_value_pool, placed_terminals, terminal_spacing)
		type_map[coord] = MapNode.NodeType.TERMINAL
		high_value_pool.erase(coord)
		placed_terminals.append(coord)

		# Progress & Yield
		items_placed_count += 1
		if Time.get_ticks_msec() - frame_start_time > max_frame_time_ms:
			# Calculate % within the 0-90 range
			var percent = (float(items_placed_count) / total_heavy_items) * 99.0
			map_generation_progress.emit(percent, 100.0)

			await get_tree().process_frame
			frame_start_time = Time.get_ticks_msec()

	# --- 5. DISTRIBUTE ELITES (Spaced Out) ---
	# We want Elites spaced away from EACH OTHER, and ideally away from Start.
	var placed_elites = []
	var elite_spacing = 5

	for i in range(num_elites):
		if high_value_pool.is_empty(): break

		var coord = _pick_distant_coord(high_value_pool, placed_elites, elite_spacing)
		type_map[coord] = MapNode.NodeType.ELITE
		high_value_pool.erase(coord)
		placed_elites.append(coord)

	# --- 6. DISTRIBUTE RANDOM REWARDS ---
	# For rewards, simple shuffling is usually fine,
	# but we use the remaining high_value_pool.
	high_value_pool.shuffle()

	var _assign_random = func(type, count):
		for i in range(count):
			if high_value_pool.is_empty(): break
			var c = high_value_pool.pop_back()
			type_map[c] = type

	_assign_random.call(MapNode.NodeType.REWARD, num_rewards)
	_assign_random.call(MapNode.NodeType.REWARD_2, num_uncommon_rewards)
	_assign_random.call(MapNode.NodeType.REWARD_3, num_rare_rewards)
	_assign_random.call(MapNode.NodeType.EVENT, num_events)

	# --- 7. FILL COMBAT ---
	# Now we recombine the buffer zone so enemies can spawn near start
	var combat_pool = high_value_pool + start_buffer_zone
	combat_pool.shuffle()

	# Optional: Prevent combat on the literal adjacent nodes to start?
	# For now, we just let them spawn anywhere remaining.

	for i in range(min(num_combats, combat_pool.size())):
		var c = combat_pool.pop_back()
		type_map[c] = MapNode.NodeType.COMBAT

	return type_map

func _pick_distant_coord(candidate_pool: Array, existing_group: Array, min_dist: int) -> Vector2i:
	# 1. If no existing group, just pick random
	if existing_group.is_empty():
		return candidate_pool.pick_random()

	# 2. Attempt to find a valid spot, lowering standards if needed
	var current_dist_check = min_dist

	while current_dist_check >= 0:
		var valid_subset = []

		for candidate in candidate_pool:
			var is_valid = true
			for existing in existing_group:
				if _get_hex_distance(candidate, existing) < current_dist_check:
					is_valid = false
					break

			if is_valid:
				valid_subset.append(candidate)

		# Found valid spots? Pick one!
		if not valid_subset.is_empty():
			return valid_subset.pick_random()

		# Map too crowded? Lower standards and try again.
		current_dist_check -= 1

	# Fallback (Should logically never reach here if dist reduces to 0)
	return candidate_pool.pick_random()

func get_save_data() -> Dictionary:
	var node_states = {}

	# 1. Serialize Node States
	for coords in grid_nodes:
		var node = grid_nodes[coords]
		# We key by String because JSON doesn't support Vector2i keys
		var key = var_to_str(coords)
		node_states[key] = {
			"state": node.state,
			"visited": node.has_been_visited,
			"aware": node.is_aware
		}

	# 2. Serialize Terminal Memory
	# We need to convert Vector2i keys to strings here too
	var serializable_terminals = {}
	for coords in terminal_memory:
		var key = var_to_str(coords)
		serializable_terminals[key] = terminal_memory[coords]

	return {
		"current_alert": current_alert,
		"total_nodes": total_nodes,
		"nodes_done": nodes_done,
		"current_coords": var_to_str(current_node.grid_coords),
		"node_data": node_states,
		"terminal_memory": serializable_terminals
	}
