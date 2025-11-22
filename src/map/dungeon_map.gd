extends Node2D
class_name DungeonMap

signal interaction_requested(node: MapNode)

const ALERT_LOW_THRESHOLD = 25
const ALERT_MED_THRESHOLD = 76

@onready var camera: Camera2D = $Camera2D
@onready var hud: Control = $CanvasLayer/HUD
@onready var alert_gauge: ProgressBar = $CanvasLayer/HUD/AlertGauge
@onready var alert_label: Label = $CanvasLayer/HUD/AlertGauge/Label
@onready var parallax_bg: Parallax2D = $Parallax2D
@onready var bg_sprite: Sprite2D = $Parallax2D/Sprite2D
@onready var background: Control = $Background

# --- Configuration ---
@export_group("Map Dimensions")
@export var map_length: int = 12
@export var map_height: int = 12

# --- Game Rules ---
@export_group("Map Rules")
@export var vision_range: int = 1

# --- Node Distribution Settings ---
@export_group("Node Counts")
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
@export var map_node_scene: PackedScene
@export var background_texture: Texture2D
@export_range(0.0, 5.0) var background_blur: float = 0.0 # NEW: Controls blur amount

# --- Internal Data ---
var hex_width: float
var hex_height: float
var grid_nodes = {}
var _map_center_pos: Vector2 = Vector2.ZERO
var _pre_battle_zoom: Vector2 = Vector2.ONE
var _pre_battle_camera_pos: Vector2 = Vector2.ZERO
var alert_tween: Tween

# --- Hex Values ---
var hex_size: float = 50.0
var gap: float = 40.0

# --- Dungeon Stats ---
var total_moves: int = 0
var current_node: MapNode = null
var current_alert: int = 0

# --- SHADER CODE ---
# A simple 9-sample blur shader we can inject dynamically
const BLUR_SHADER_CODE = """
shader_type canvas_item;
uniform float blur_amount : hint_range(0, 10) = 0.0;

void fragment() {
	if (blur_amount <= 0.0) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec4 col = vec4(0.0);
		vec2 ps = TEXTURE_PIXEL_SIZE * blur_amount;

		// Sample center and surrounding 8 points for a smooth average
		col += texture(TEXTURE, UV);
		col += texture(TEXTURE, UV + vec2(0.0, -1.0) * ps);
		col += texture(TEXTURE, UV + vec2(0.0, 1.0) * ps);
		col += texture(TEXTURE, UV + vec2(-1.0, 0.0) * ps);
		col += texture(TEXTURE, UV + vec2(1.0, 0.0) * ps);
		col += texture(TEXTURE, UV + vec2(-0.7, -0.7) * ps);
		col += texture(TEXTURE, UV + vec2(0.7, -0.7) * ps);
		col += texture(TEXTURE, UV + vec2(-0.7, 0.7) * ps);
		col += texture(TEXTURE, UV + vec2(0.7, 0.7) * ps);

		COLOR = col / 9.0;
	}
}
"""

enum MapState { LOADING, PLAYING, LOCKED }
var current_map_state: MapState = MapState.LOADING


func _ready():
	randomize()
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0

	alert_gauge.self_modulate = Color.MEDIUM_SEA_GREEN
	alert_gauge.modulate.a = 0.0
	alert_gauge.value = current_alert
	alert_label.text = str(int(alert_gauge.value)) + "%"

	_setup_camera()
	_setup_background()
	await generate_hex_grid()

	var tween = create_tween()
	tween.tween_property(alert_gauge, "modulate:a", 1.0, 0.75)\
		.set_delay(0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished

	current_map_state = MapState.PLAYING
	print("Map loaded and input enabled.")

func _setup_camera():
	camera.make_current()

func _setup_background():
	var shader_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = BLUR_SHADER_CODE
	shader_material.shader = shader
	bg_sprite.material = shader_material

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		generate_hex_grid()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-zoom_step)

func _zoom_camera(step: float):
	if not camera: return
	var target_zoom = camera.zoom + Vector2(step, step)
	target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
	target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)
	camera.zoom = target_zoom

func generate_hex_grid():
	print("Generating Map | Length: %d | Height: %d" % [map_length, map_height])
	total_moves = 0
	current_node = null
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0

	if not map_node_scene:
		print("Error: Please assign 'Map Node Scene' in the Inspector!")
		return

	for child in $Background.get_children():
		child.queue_free()
	grid_nodes.clear()
	alert_gauge.value = 0

	# --- 1. Generate Logic (Same as before) ---
	var valid_coords = {}
	var start_pos = Vector2(100, 200)
	var center_y = floor(map_height / 2.0)
	var center_row_is_even = (int(center_y) % 2 == 0)
	var center_shift = 0.5 if center_row_is_even else 0.0
	var visual_center_x = (map_length - 1) / 2.0 + center_shift
	var min_bounds = Vector2(99999, 99999)
	var max_bounds = Vector2(-99999, -99999)

	for y in range(map_height):
		var dist_y = abs(y - center_y)
		var x_count = map_length - dist_y
		if x_count <= 0: continue

		var current_row_is_even = (y % 2 == 0)
		var current_shift = 0.5 if current_row_is_even else 0.0
		var row_half_width = (x_count - 1) / 2.0
		var x_start = round(visual_center_x - current_shift - row_half_width)

		for i in range(x_count):
			var x = x_start + i
			var grid_pos = Vector2i(x, y)
			var x_pos = x * (hex_width + gap)
			var y_pos = y * (hex_height * 0.67 + gap)
			if y % 2 == 0: x_pos += (hex_width + gap) / 2.0
			var final_pos = start_pos + Vector2(x_pos, y_pos)
			valid_coords[grid_pos] = final_pos
			min_bounds.x = min(min_bounds.x, final_pos.x)
			min_bounds.y = min(min_bounds.y, final_pos.y)
			max_bounds.x = max(max_bounds.x, final_pos.x)
			max_bounds.y = max(max_bounds.y, final_pos.y)

	# --- 2. Create Nodes (Invisible) ---
	var node_types = _distribute_node_types(valid_coords.keys(), center_y)
	var hex_points = _get_pointy_top_hex_points(hex_size)

	# We keep a list so we can sort them for the animation
	var nodes_to_animate: Array[MapNode] = []

	for coords in valid_coords.keys():
		var screen_pos = valid_coords[coords]
		var assigned_type = node_types[coords]
		# Create the node (it defaults to alpha 0.0 now)
		var new_node = _create_map_node(coords.x, coords.y, screen_pos, hex_points, assigned_type)
		nodes_to_animate.append(new_node)

	await _update_background_transform(min_bounds, max_bounds)

	# --- 3. Identify Start Node ---
	var center_start_x = round(visual_center_x - center_shift - (map_length - 1) / 2.0)
	var start_coords = Vector2i(center_start_x, center_y)
	var start_node = null

	if grid_nodes.has(start_coords):
		start_node = grid_nodes[start_coords]
	elif grid_nodes.size() > 0:
		start_node = grid_nodes.values()[0]

	if start_node and camera:
		camera.position = start_node.position
		camera.zoom = Vector2(1.0, 1.0)

	# --- 4. The Animation Sequence ---
	await get_tree().create_timer(0.5).timeout
	var start_tween = create_tween()
	start_tween.tween_property(start_node, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_OUT)
	await start_tween.finished
	AudioManager.play_sfx("terminal")

	# B. Sort the rest Left-to-Right
	nodes_to_animate.sort_custom(func(a, b):
		# Sort by X first
		if a.grid_coords.x != b.grid_coords.x:
			return a.grid_coords.x < b.grid_coords.x
		# Then by Y (top to bottom) for clean columns
		return a.grid_coords.y < b.grid_coords.y
	)

	# C. The "Wave" Tween
	var wave_tween = create_tween().set_parallel(true)
	var current_col_x = -9999
	var delay_timer = 0.0
	var col_delay_step = 0.1

	for node in nodes_to_animate:
		if node == start_node: continue # Don't animate start node again

		# If we moved to a new column X, increase the delay
		if node.grid_coords.x != current_col_x:
			current_col_x = node.grid_coords.x
			delay_timer += col_delay_step

		# Animate alpha to 1.0 with the calculated delay
		wave_tween.tween_property(node, "modulate:a", 1.0, 0.3)\
			.set_delay(delay_timer)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

	# D. Wait for the whole map to finish appearing
	await wave_tween.finished

	if start_node:
		_move_player_to(start_node, true)

func complete_current_node():
	if current_node:
		current_node.set_state(MapNode.NodeState.COMPLETED)
		await _update_vision()
		# Add rewards, xp, etc here

func enter_battle_visuals(duration: float = 1.5):
	# 1. Save state
	_pre_battle_zoom = camera.zoom
	_pre_battle_camera_pos = camera.position

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# 2. Fade OUT Map Elements (Hexes)
	tween.tween_property(background, "modulate:a", 0.0, duration / 2)

# 3. Fade OUT Map HUD (Alert Gauge)
	tween.tween_property(hud, "modulate:a", 0.0, duration / 2)

	# 4. Move Camera to Center of Background
	tween.tween_property(camera, "position", _map_center_pos, duration)

	# 5. Zoom OUT (to min_zoom, or a specific 'battle_zoom' if you prefer)
	# (Remember in Godot 4: Lower values = Zoomed Out / Wider View)
	var battle_zoom_vec = Vector2(min_zoom, min_zoom)
	tween.tween_property(camera, "zoom", battle_zoom_vec, duration)

	 #6. (Optional) Clear the blur so the background looks sharp for battle
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

	(bg_sprite.material as ShaderMaterial).set_shader_parameter("blur_amount", background_blur)

	var padding = Vector2(hex_width * 4, hex_height * 4)
	var grid_center = (min_b + max_b) / 2.0
	_map_center_pos = grid_center
	var grid_size = (max_b - min_b) + padding

	var max_dimension = max(grid_size.x, grid_size.y)
	var depth_factor = clamp(1.0 - (max_dimension / 5000.0), 0.1, 0.9)

	parallax_bg.scroll_scale = Vector2(depth_factor, depth_factor)

	var tex_size = background_texture.get_size()
	var required_scale = Vector2.ONE
	var world_coverage = grid_size * (1.0 + (1.0 - depth_factor))

	required_scale.x = world_coverage.x / tex_size.x
	required_scale.y = world_coverage.y / tex_size.y

	var final_scale = max(required_scale.x, required_scale.y)
	bg_sprite.scale = Vector2(final_scale, final_scale)
	parallax_bg.scroll_offset = grid_center

func _distribute_node_types(all_coords: Array, center_y: int) -> Dictionary:
	var type_map = {}
	for c in all_coords: type_map[c] = MapNode.NodeType.UNKNOWN

	# 1. FIND START (Entrance)
	# Absolute Leftmost node on the center row (or just absolute leftmost)
	var min_x = 9999
	for c in all_coords:
		if c.y == center_y and c.x < min_x:
			min_x = c.x
	var start_node = Vector2i(min_x, center_y)

	# 2. FIND BOSS (Exit)
	# Sort all nodes by X position (Descending / Right-to-Left)
	var sorted_by_x = all_coords.duplicate()
	sorted_by_x.sort_custom(func(a, b): return a.x > b.x)

	# Take the top 7 right-most nodes as candidates
	var boss_candidates_count = min(7, sorted_by_x.size())
	var boss_pool = sorted_by_x.slice(0, boss_candidates_count)

	# Pick one, but ensure it's not the start node (sanity check)
	var boss_node = boss_pool.pick_random()
	while boss_node == start_node and boss_pool.size() > 1:
		boss_node = boss_pool.pick_random()

	type_map[boss_node] = MapNode.NodeType.BOSS

	# 3. DISTRIBUTE GOOD NODES
	var good_candidates = []
	for c in all_coords:
		if c == start_node or c == boss_node: continue

		# NEW: Banned Zone (Distance > 1 from start)
		# Prevents good nodes from spawning adjacent to start
		if _get_hex_distance(start_node, c) <= 1:
			continue

		good_candidates.append(c)

	good_candidates.shuffle()

	var _assign_good = func(type, count):
		for i in range(count):
			if good_candidates.is_empty(): break
			var coord = good_candidates.pop_back()
			type_map[coord] = type

	_assign_good.call(MapNode.NodeType.ELITE, num_elites)
	_assign_good.call(MapNode.NodeType.REWARD, num_rewards)
	_assign_good.call(MapNode.NodeType.REWARD_2, num_uncommon_rewards)
	_assign_good.call(MapNode.NodeType.REWARD_3, num_rare_rewards)
	_assign_good.call(MapNode.NodeType.TERMINAL, num_terminals)
	_assign_good.call(MapNode.NodeType.EVENT, num_events)

	# 4. FILL COMBAT
	var empty_spots = []
	for c in all_coords:
		if c == start_node or c == boss_node: continue
		if type_map[c] == MapNode.NodeType.UNKNOWN:
			empty_spots.append(c)
	empty_spots.shuffle()

	for i in range(min(num_combats, empty_spots.size())):
		var c = empty_spots.pop_back()
		type_map[c] = MapNode.NodeType.COMBAT

	return type_map

func _create_map_node(grid_x, grid_y, screen_pos, points, type) -> MapNode:
	var node = map_node_scene.instantiate()
	node.position = screen_pos
	node.name = "Hex_%d_%d" % [grid_x, grid_y]
	node.modulate.a = 0.0

	$Background.add_child(node)
	node.setup(Vector2i(grid_x, grid_y), points, type)

	node.node_clicked.connect(_on_node_clicked)
	grid_nodes[Vector2i(grid_x, grid_y)] = node

	return node

func _on_node_clicked(target_node: MapNode):
	if target_node == current_node: return
	if current_map_state != MapState.PLAYING: return

	var dist = _get_hex_distance(current_node.grid_coords, target_node.grid_coords)
	if dist > 1:
		print("Too far! Dist: ", dist)
		return
	_move_player_to(target_node)

func _move_player_to(target_node: MapNode, is_start: bool = false):
	# 1. Handle Node Logic
	if current_node:
		current_node.set_is_current(false)

	current_node = target_node
	target_node.set_is_current(true)

	# 2. Handle Camera
	_move_camera_to_player(is_start)

	if is_start:
		target_node.set_state(MapNode.NodeState.COMPLETED)
		_update_alert_visuals() # Ensure UI is correct on start
		_update_vision()
		return

	# 3. Handle Gameplay Logic
	total_moves += 1
	var is_revisit = target_node.state == MapNode.NodeState.COMPLETED

	# Calculate how much alert to add based on current tier
	var alert_gain = _calculate_alert_gain(is_revisit)

	# Apply the change (Visuals update automatically inside this function)
	modify_alert(alert_gain)

	# Update vision AFTER alert change (in case vision_range changed)
	_update_vision()

	if not is_revisit:
		if target_node.type == MapNode.NodeType.TERMINAL:
			modify_alert(-25)
			complete_current_node()
		else:
			interaction_requested.emit(target_node)

# --- NEW: Logic to determine cost ---
func _calculate_alert_gain(is_revisit: bool) -> int:
	if current_alert < ALERT_LOW_THRESHOLD:
		return 1 if is_revisit else 4
	elif current_alert < ALERT_MED_THRESHOLD:
		return 2 if is_revisit else 5
	else:
		return 3 if is_revisit else 6

# --- NEW: The Single Source of Truth ---
# Call this function for adding OR removing alert (pass negative numbers to reduce)
func modify_alert(amount: int):
	current_alert = clamp(current_alert + amount, 0, 100)
	_update_alert_visuals()

# --- NEW: Handles all UI and State changes based on the value ---
func _update_alert_visuals():
	# 1. Determine the Target State & Color
	# We do this logic immediately so the game state is correct
	var target_color: Color

	if current_alert < ALERT_LOW_THRESHOLD:
		target_color = Color.MEDIUM_SEA_GREEN
		vision_range = 2
	elif current_alert < ALERT_MED_THRESHOLD:
		target_color = Color.GOLDENROD
		vision_range = 1
	else:
		target_color = Color.ORANGE_RED
		vision_range = 0

	# 2. Setup the Tween
	if alert_tween and alert_tween.is_running():
		alert_tween.kill() # Stop any previous movement

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
	alert_tween.tween_property(alert_gauge, "self_modulate", target_color, duration)

# --- Helper Function called by the Tween ---
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

func _update_vision():
	if vision_range <= 0: return
	var center_coords = current_node.grid_coords

	# 1. Collect nodes that actually need revealing
	var nodes_to_reveal: Array[MapNode] = []

	for node in grid_nodes.values():
		# Skip nodes that don't need updates
		if node.state != MapNode.NodeState.HIDDEN: continue

		var dist = _get_hex_distance(center_coords, node.grid_coords)
		if dist <= vision_range:
			nodes_to_reveal.append(node)

	# 2. The Fix: If nobody needs revealing, stop here.
	# This prevents the "started with no Tweeners" error.
	if nodes_to_reveal.is_empty():
		return

	# 3. NOW it is safe to create the tween
	var tween = create_tween().set_parallel(true)

	for node in nodes_to_reveal:
		# Update logical state
		node.set_state(MapNode.NodeState.REVEALED)

		# Set initial visual state
		node.modulate.a = 0.0

		# Calculate delay
		var dist = _get_hex_distance(center_coords, node.grid_coords)
		var delay = max(0, (dist - 1) * 0.1) # Ensure delay isn't negative

		# Add to tween
		tween.tween_property(node, "modulate:a", 1.0, 0.5)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

func _get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac = _offset_to_cube(a)
	var bc = _offset_to_cube(b)
	return max(abs(ac.x - bc.x), abs(ac.y - bc.y), abs(ac.z - bc.z))

func _offset_to_cube(hex: Vector2i) -> Vector3i:
	var q = hex.x - (hex.y + (hex.y & 1)) / 2
	var r = hex.y
	var s = -q - r
	return Vector3i(q, r, s)

func _get_pointy_top_hex_points(size: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(6):
		var angle_deg = 30 + (60 * i)
		var angle_rad = deg_to_rad(angle_deg)
		pts.append(Vector2(size * cos(angle_rad), size * sin(angle_rad)))
	return pts
