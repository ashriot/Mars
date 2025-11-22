extends Node2D
class_name DungeonMap

signal interaction_requested(node: MapNode)

const ALERT_LOW_THRESHOLD = 25
const ALERT_MED_THRESHOLD = 76

@onready var camera: Camera2D = $Camera2D
@onready var hud: Control = $CanvasLayer/HUD
@onready var alert_gauge: ProgressBar = $CanvasLayer/HUD/AlertGauge
@onready var alert_label: Label = $CanvasLayer/HUD/AlertGauge/Panel/Value
@onready var parallax_bg: Parallax2D = $Parallax2D
@onready var bg_sprite: Sprite2D = $Parallax2D/Sprite2D
@onready var background: Control = $Background

# --- Configuration ---
@export_group("Map Dimensions")
@export var map_length: int = 10
@export var map_height: int = 9

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
var _calculated_depth_scale: Vector2 = Vector2.ONE
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
	AudioManager.play_music("map_1", 1.0, false, false)
	randomize()
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0

	alert_gauge.modulate = Color.MEDIUM_SEA_GREEN
	hud.modulate.a = 0.0
	alert_gauge.value = current_alert
	alert_label.text = str(int(alert_gauge.value)) + "%"

	_setup_camera()
	_setup_background()
	var map = generate_hex_grid()
	await play_intro_sequence(map)
	AudioManager.play_sfx("radiate")

	var tween = create_tween()
	tween.tween_property(hud, "modulate:a", 1.0, 0.15)\
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

func generate_hex_grid() -> Dictionary:
	print("Generating Map Logic...")

	# --- Cleanup ---
	total_moves = 0
	current_node = null
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0

	if not has_node("Background"):
		var bg_node = Node2D.new()
		bg_node.name = "Background"
		add_child(bg_node)

	for child in $Background.get_children():
		child.queue_free()
	grid_nodes.clear()
	alert_gauge.value = 0

	# --- Grid Math ---
	var valid_coords = {}
	var start_pos = Vector2(100, 200)
	var center_y = floor(map_height / 2.0)
	var visual_center_x = (map_length - 1) / 2.0 + (0.5 if int(center_y) % 2 == 0 else 0.0)
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
	var node_types = _distribute_node_types(valid_coords.keys(), center_y)
	var nodes_list: Array[MapNode] = []

	for coords in valid_coords.keys():
		# Create node (starts invisible alpha 0.0 via _create_map_node)
		var new_node = _create_map_node(coords.x, coords.y, valid_coords[coords], node_types[coords])
		nodes_list.append(new_node)

	# --- Background Setup ---
	_update_background_transform(min_bounds, max_bounds)

	# --- Find Start Node ---
	var center_start_x = round(visual_center_x - (0.5 if int(center_y) % 2 == 0 else 0.0) - (map_length - 1) / 2.0)
	var start_coords = Vector2i(center_start_x, center_y)
	var start_node = grid_nodes.get(start_coords, grid_nodes.values()[0] if not grid_nodes.is_empty() else null)

	# Return all the data needed for the animation
	return {
		"start_node": start_node,
		"nodes": nodes_list,
		"min_bounds": min_bounds,
		"max_bounds": max_bounds
	}

func play_intro_sequence(map_data: Dictionary) -> void:
	var start_node = map_data.start_node
	var nodes_to_animate = map_data.nodes

	if not camera: return

	# --- 1. SETUP "WIDE SHOT" CAMERA ---
	var grid_center = (map_data.min_bounds + map_data.max_bounds) / 2.0
	camera.position = grid_center
	parallax_bg.scroll_scale = Vector2.ONE

	# Calculate Wide Zoom
	var vp_size = get_viewport_rect().size
	var bg_current_size = bg_sprite.texture.get_size() * bg_sprite.scale
	var wide_zoom = max(vp_size.x / bg_current_size.x, vp_size.y / bg_current_size.y)
	camera.zoom = Vector2(wide_zoom, wide_zoom)

	# --- 2. ANIMATE "WAVE" REVEAL ---

	# Reveal Start Node immediately
	var start_tween = create_tween()
	start_tween.tween_property(start_node, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	await start_tween.finished
	AudioManager.play_sfx("terminal")

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

		await cam_tween.finished

		# Hand over control
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

	(bg_sprite.material as ShaderMaterial).set_shader_parameter("blur_amount", background_blur)

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
	current_node.hex_sprite.modulate = Color.DARK_GRAY
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
	var is_revisit = target_node.has_been_visited
	target_node.has_been_visited = true
	var alert_gain = _calculate_alert_gain(is_revisit)

	modify_alert(alert_gain)

	# Update vision AFTER alert change (in case vision_range changed)
	_update_vision()

	if target_node.state != MapNode.NodeState.COMPLETED:
		interaction_requested.emit(target_node)

func _calculate_alert_gain(is_revisit: bool) -> int:
	if current_alert < ALERT_LOW_THRESHOLD:
		return 1 if is_revisit else 4
	elif current_alert < ALERT_MED_THRESHOLD:
		return 2 if is_revisit else 5
	else:
		return 3 if is_revisit else 6

func modify_alert(amount: int):
	current_alert = clamp(current_alert + amount, 0, 100)
	_update_alert_visuals()

func _update_alert_visuals():
	# 1. Determine the Target State & Color
	# We do this logic immediately so the game state is correct
	var target_color: Color

	if current_alert < ALERT_LOW_THRESHOLD:
		target_color = Color(0.419, 1.063, 0.419)
		vision_range = 2
	elif current_alert < ALERT_MED_THRESHOLD:
		target_color = Color(1.437, 1.226, 0.0, 1.0)
		vision_range = 1
	else:
		target_color = Color(1.437, 0.234, 0.0, 1.0)
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
