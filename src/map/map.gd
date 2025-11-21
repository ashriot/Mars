extends Node2D

# --- Configuration ---
@export var map_length: int = 15
@export var map_height: int = 7
@export var hex_size: float = 50.0
@export var gap: float = 40.0

# --- Node Distribution Settings ---
@export_group("Node Counts")
@export var num_combats: int = 10
@export var num_elites: int = 3
@export var num_events: int = 4
@export var num_rewards: int = 3
# "Unknown" nodes will fill any empty space remaining

# --- Game Rules ---
@export var vision_range: int = 1
var total_moves: int = 0
var current_node: MapNode = null

# --- Assets ---
@export var map_node_scene: PackedScene

# --- Internal Data ---
var hex_width: float
var hex_height: float
var grid_nodes = {}

func _ready():
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0
	vision_range = 2

	if has_node("AlertGauge"):
		$AlertGauge.modulate = Color.LAWN_GREEN

	generate_hex_grid()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		generate_hex_grid()

func generate_hex_grid():
	print("Generating Map | Length: %d | Height: %d" % [map_length, map_height])

	# 1. Cleanup
	total_moves = 0
	current_node = null
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0

	if not map_node_scene:
		print("Error: Please assign 'Map Node Scene' in the Inspector!")
		return

	if has_node("Background"):
		for child in $Background.get_children():
			child.queue_free()
	else:
		print("Error: Missing 'Background' node.")
		return

	grid_nodes.clear()
	if has_node("AlertGauge"): $AlertGauge.value = 0

	# 2. Calculate Coordinates & Visual Positions
	var valid_coords = {}

	var start_pos = Vector2(80, 200)
	var center_y = floor(map_height / 2.0)
	var center_row_is_even = (int(center_y) % 2 == 0)
	var center_shift = 0.5 if center_row_is_even else 0.0
	var visual_center_x = (map_length - 1) / 2.0 + center_shift

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

			# Visual Math
			var x_pos = x * (hex_width + gap)
			var y_pos = y * (hex_height * 0.75 + gap)
			if y % 2 == 0: x_pos += (hex_width + gap) / 2.0
			var final_pos = start_pos + Vector2(x_pos, y_pos)

			valid_coords[grid_pos] = final_pos

	# 3. DISTRIBUTE TYPES
	var node_types = _distribute_node_types(valid_coords.keys(), center_y)

	# 4. INSTANTIATE NODES
	var hex_points = _get_pointy_top_hex_points(hex_size)

	for coords in valid_coords.keys():
		var screen_pos = valid_coords[coords]
		var assigned_type = node_types[coords]
		_create_map_node(coords.x, coords.y, screen_pos, hex_points, assigned_type)

	# 5. Start Game
	var center_start_x = round(visual_center_x - center_shift - (map_length - 1) / 2.0)
	var start_coords = Vector2i(center_start_x, center_y)

	if grid_nodes.has(start_coords):
		_move_player_to(grid_nodes[start_coords], true)
	else:
		if grid_nodes.size() > 0:
			_move_player_to(grid_nodes.values()[0], true)

# --- TYPE DISTRIBUTION ALGORITHM ---
func _distribute_node_types(all_coords: Array, center_y: int) -> Dictionary:
	var type_map = {}

	# A. Initialize Everything to UNKNOWN
	for c in all_coords:
		type_map[c] = MapNode.NodeType.UNKNOWN

	# B. Identify Key Locations (Start / Boss)
	var min_x = 9999
	var max_x = -9999

	# Find limits of center row
	for c in all_coords:
		if c.y == center_y:
			if c.x < min_x: min_x = c.x
			if c.x > max_x: max_x = c.x

	var start_node = Vector2i(min_x, center_y)
	var boss_node = Vector2i(max_x, center_y)

	# Set Fixed Nodes
	# We keep start as UNKNOWN or you can make it EVENT if you want a freebie
	type_map[boss_node] = MapNode.NodeType.BOSS

	# D. Gather Candidates for "Good" Nodes
	var good_candidates = []

	for c in all_coords:
		if c == start_node or c == boss_node: continue

		good_candidates.append(c)

	# E. Randomly Distribute "Good" Nodes (Uniform Distribution)
	good_candidates.shuffle()

	# Helper to assign from the shuffled deck
	var _assign_good = func(type, count):
		for i in range(count):
			if good_candidates.is_empty(): break
			var coord = good_candidates.pop_back()
			type_map[coord] = type

	_assign_good.call(MapNode.NodeType.ELITE, num_elites)
	_assign_good.call(MapNode.NodeType.REWARD, num_rewards)
	_assign_good.call(MapNode.NodeType.EVENT, num_events)

	# F. Fill Remaining Spots with Combat
	# Combat can go ANYWHERE that is currently UNKNOWN (including the main road)
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

# --- NODE CREATION ---
func _create_map_node(grid_x, grid_y, screen_pos, points, type):
	var node = map_node_scene.instantiate()
	node.position = screen_pos
	node.name = "Hex_%d_%d" % [grid_x, grid_y]

	$Background.add_child(node)
	node.setup(Vector2i(grid_x, grid_y), points, type)

	node.node_clicked.connect(_on_node_clicked)
	grid_nodes[Vector2i(grid_x, grid_y)] = node

# --- GAMEPLAY LOGIC ---
func _on_node_clicked(target_node: MapNode):
	if target_node == current_node: return

	if current_node != null:
		var dist = _get_hex_distance(current_node.grid_coords, target_node.grid_coords)
		if dist > 1:
			print("Too far! Dist: ", dist)
			return

	_move_player_to(target_node)

func _move_player_to(target_node: MapNode, is_start: bool = false):
	if current_node != null:
		current_node.set_is_current(false)

	current_node = target_node
	target_node.set_state(MapNode.NodeState.COMPLETED)
	target_node.set_is_current(true)

	if not is_start:
		total_moves += 1
		if has_node("AlertGauge"):
			if $AlertGauge.value < 33:
				$AlertGauge.modulate = Color.LAWN_GREEN
				$AlertGauge.value += 4
				vision_range = 2
			elif $AlertGauge.value < 66:
				$AlertGauge.modulate = Color.GOLD
				$AlertGauge.value += 5
				vision_range = 1
			else:
				$AlertGauge.modulate = Color.RED
				$AlertGauge.value += 6
				vision_range = 0

		print("Moved to ", target_node.grid_coords, ". Total Moves: ", total_moves)

	_update_vision()

func _update_vision():
	if vision_range <= 0: return
	var center_coords = current_node.grid_coords
	for node in grid_nodes.values():
		if node.state == MapNode.NodeState.COMPLETED: continue

		var dist = _get_hex_distance(center_coords, node.grid_coords)

		if dist <= vision_range and node.state == MapNode.NodeState.HIDDEN:
			node.set_state(MapNode.NodeState.REVEALED)

# --- UTILITIES ---
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
