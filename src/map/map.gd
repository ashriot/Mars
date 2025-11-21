extends Node2D

# --- Configuration ---
@export var map_length: int = 12     # Controls the WIDTH of the center row (Difficulty)
@export var map_height: int = 7     # Controls the HEIGHT (Must be odd: 5, 7, 9)
@export var hex_size: float = 50.0
@export var gap: float = 5.0

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
	generate_hex_grid()

func _input(event):
	# Press 'R' to regenerate (prevents accidental clicks resetting map)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		generate_hex_grid()

func generate_hex_grid():
	print("Generating Map | Length: %d | Height: %d" % [map_length, map_height])

	total_moves = 0
	current_node = null

	# Recalculate dimensions
	hex_width = sqrt(3.0) * hex_size
	hex_height = hex_size * 2.0

	if not map_node_scene:
		print("Error: Please assign 'Map Node Scene' in the Inspector!")
		return

	for child in get_children():
		child.queue_free()
	grid_nodes.clear()

	var start_pos = Vector2(100, 100)
	var hex_points = _get_pointy_top_hex_points(hex_size)

	# --- ROBUST SYMMETRY LOGIC ---

	# 1. Identify the Center Row
	var center_y = floor(map_height / 2.0)

	# 2. Calculate the "Visual Center" of the map in grid units.
	#    If the center row is Even (y%2==0), it is shifted right by 0.5.
	#    We need to lock onto this visual center for all other rows.
	var center_row_is_even = (int(center_y) % 2 == 0)
	var center_shift = 0.5 if center_row_is_even else 0.0

	#    Visual Center = Half the length + the shift
	var visual_center_x = (map_length - 1) / 2.0 + center_shift

	for y in range(map_height):
		var dist_y = abs(y - center_y)

		# Row Width: shrinks by 1 for every step away from center
		var x_count = map_length - dist_y
		if x_count <= 0: continue # Skip if row shrinks to nothing

		# Row Shift: Check if THIS row is shifted
		var current_row_is_even = (y % 2 == 0)
		var current_shift = 0.5 if current_row_is_even else 0.0

		# START INDEX CALCULATION:
		# We work backwards from the Visual Center.
		# Visual_Center = Start_X + Current_Shift + (Row_Width - 1) / 2.0
		# Therefore:
		# Start_X = Visual_Center - Current_Shift - (Row_Width - 1) / 2.0
		var row_half_width = (x_count - 1) / 2.0
		var x_start = round(visual_center_x - current_shift - row_half_width)

		for i in range(x_count):
			var x = x_start + i

			# Calculate visual position
			var x_pos = x * (hex_width + gap)
			var y_pos = y * (hex_height * 0.75 + gap)

			# Shift Even rows to the right
			if y % 2 == 0:
				x_pos += (hex_width + gap) / 2.0

			var final_pos = start_pos + Vector2(x_pos, y_pos)
			_create_map_node(x, y, final_pos, hex_points)

	# --- START GAME ---
	# Find the start node.
	# We look for the leftmost node in the center row.
	# Based on our math, we can calculate exactly what that index is.
	var center_start_x = round(visual_center_x - center_shift - (map_length - 1) / 2.0)
	var start_coords = Vector2i(center_start_x, center_y)

	if grid_nodes.has(start_coords):
		_move_player_to(grid_nodes[start_coords], true)
	else:
		print("Warning: Start node ", start_coords, " missing. Using fallback.")
		if grid_nodes.size() > 0:
			_move_player_to(grid_nodes.values()[0], true)

func _create_map_node(grid_x, grid_y, screen_pos, points):
	var node = map_node_scene.instantiate()
	node.position = screen_pos
	node.name = "Hex_%d_%d" % [grid_x, grid_y]

	var random_type = MapNode.NodeType.values().pick_random()
	node.setup(Vector2i(grid_x, grid_y), points, random_type)

	node.node_clicked.connect(_on_node_clicked)
	add_child(node)
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
	current_node = target_node
	target_node.set_state(MapNode.NodeState.COMPLETED)

	if not is_start:
		total_moves += 1
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
