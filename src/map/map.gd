extends Node2D

@onready var alert_gauge: ProgressBar = $CanvasLayer/AlertGauge
@onready var alert_label: Label = $CanvasLayer/AlertGauge/Label
@onready var parallax_bg: Parallax2D = $Parallax2D
@onready var bg_sprite: Sprite2D = $Parallax2D/Sprite2D

# --- Configuration ---
@export_group("Map Dimensions")
@export var map_length: int = 12
@export var map_height: int = 12

# --- Game Rules ---
@export_group("Map Rules")
@export var vision_range: int = 1
var total_moves: int = 0
var current_node: MapNode = null

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
var camera: Camera2D

# --- Hex Values ---
var hex_size: float = 50.0
var gap: float = 40.0

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

func _ready():
	randomize()
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0
	vision_range = 2

	alert_gauge.self_modulate = Color.MEDIUM_SEA_GREEN
	alert_gauge.value = 0
	alert_label.text = str(int(alert_gauge.value)) + "%"

	_setup_camera()
	_setup_background() # Initialize the parallax nodes
	generate_hex_grid()

func _setup_camera():
	if has_node("Camera2D"):
		camera = $Camera2D
	else:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
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

	# Use explicit Background container for nodes so they sit ON TOP of parallax
	if not has_node("Background"):
		var bg_node = Node2D.new()
		bg_node.name = "Background"
		add_child(bg_node)

	for child in $Background.get_children():
		child.queue_free()
	grid_nodes.clear()
	alert_gauge.value = 0

	var valid_coords = {}

	var start_pos = Vector2(100, 200)
	var center_y = floor(map_height / 2.0)
	var center_row_is_even = (int(center_y) % 2 == 0)
	var center_shift = 0.5 if center_row_is_even else 0.0
	var visual_center_x = (map_length - 1) / 2.0 + center_shift

	# We need to track bounds to size the background later
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

			# Track bounds
			min_bounds.x = min(min_bounds.x, final_pos.x)
			min_bounds.y = min(min_bounds.y, final_pos.y)
			max_bounds.x = max(max_bounds.x, final_pos.x)
			max_bounds.y = max(max_bounds.y, final_pos.y)

	var node_types = _distribute_node_types(valid_coords.keys(), center_y)
	var hex_points = _get_pointy_top_hex_points(hex_size)

	for coords in valid_coords.keys():
		var screen_pos = valid_coords[coords]
		var assigned_type = node_types[coords]
		_create_map_node(coords.x, coords.y, screen_pos, hex_points, assigned_type)

	# --- UPDATE BACKGROUND ---
	_update_background_transform(min_bounds, max_bounds)

	var center_start_x = round(visual_center_x - center_shift - (map_length - 1) / 2.0)
	var start_coords = Vector2i(center_start_x, center_y)

	if grid_nodes.has(start_coords):
		_move_player_to(grid_nodes[start_coords], true)
	else:
		if grid_nodes.size() > 0:
			_move_player_to(grid_nodes.values()[0], true)

func _update_background_transform(min_b: Vector2, max_b: Vector2):
	bg_sprite.texture = background_texture

	(bg_sprite.material as ShaderMaterial).set_shader_parameter("blur_amount", background_blur)

	var padding = Vector2(hex_width * 4, hex_height * 4)
	var grid_center = (min_b + max_b) / 2.0
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
func _create_map_node(grid_x, grid_y, screen_pos, points, type):
	var node = map_node_scene.instantiate()
	node.position = screen_pos
	node.name = "Hex_%d_%d" % [grid_x, grid_y]

	$Background.add_child(node)
	node.setup(Vector2i(grid_x, grid_y), points, type)

	node.node_clicked.connect(_on_node_clicked)
	grid_nodes[Vector2i(grid_x, grid_y)] = node

func _on_node_clicked(target_node: MapNode):
	if target_node == current_node: return
	if current_node != null:
		var dist = _get_hex_distance(current_node.grid_coords, target_node.grid_coords)
		if dist > 1:
			print("Too far! Dist: ", dist)
			return
	_move_player_to(target_node)

func _move_player_to(target_node: MapNode, is_start: bool = false):
	if current_node:
		current_node.set_is_current(false)
	current_node = target_node
	var been = target_node.state == MapNode.NodeState.COMPLETED
	if not been: target_node.set_state(MapNode.NodeState.COMPLETED)
	target_node.set_is_current(true)

	if not is_start:
		total_moves += 1
		if alert_gauge.value < 19:
			alert_gauge.self_modulate = Color.MEDIUM_SEA_GREEN
			alert_gauge.value += 4 if not been else 1
			vision_range = 2
		elif alert_gauge.value < 69:
			alert_gauge.self_modulate = Color.GOLDENROD
			alert_gauge.value += 5 if not been else 2
			vision_range = 1
		else:
			alert_gauge.self_modulate = Color.ORANGE_RED
			alert_gauge.value += 6 if not been else 3
			vision_range = 0
		alert_label.text = str(int(alert_gauge.value)) + "%"

		#print("Moved to ", target_node.grid_coords, ". Total Moves: ", total_moves)

	_update_vision()
	_move_camera_to_player(is_start)

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
	for node in grid_nodes.values():
		if node.state == MapNode.NodeState.COMPLETED: continue
		var dist = _get_hex_distance(center_coords, node.grid_coords)
		if dist <= vision_range and node.state == MapNode.NodeState.HIDDEN:
			node.set_state(MapNode.NodeState.REVEALED)

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
