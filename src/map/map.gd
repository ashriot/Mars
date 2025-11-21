extends Node2D

# --- Configuration ---
const GRID_HEIGHT = 7
const HEX_SIZE = 50.0
const GAP = 5.0
const MAP_RADIUS = 3

# --- Game Rules ---
# 0 = Blind (Only see current)
# 1 = See Neighbors
# 2 = See Neighbors + Neighbors of Neighbors
@export var vision_range: int = 1
var total_moves: int = 0
var current_node: MapNode = null

# --- Texture Assets ---
@export_group("Event Icons")
@export var icon_combat: Texture2D
@export var icon_elite: Texture2D
@export var icon_boss: Texture2D
@export var icon_reward: Texture2D
@export var icon_event: Texture2D

# --- Internal Data ---
var hex_width = sqrt(3.0) * HEX_SIZE
var hex_height = HEX_SIZE * 2.0
var grid_nodes = {} # Key: Vector2i(x,y), Value: MapNode

func _ready():
	generate_hex_grid()

func _input(event):
	# CHANGED: Using explicit 'R' key to prevent accidental regeneration on click
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		generate_hex_grid()

func generate_hex_grid():
	# Reset Game State
	total_moves = 0
	current_node = null

	for child in get_children():
		child.queue_free()
	grid_nodes.clear()

	hex_width = sqrt(3.0) * HEX_SIZE
	hex_height = HEX_SIZE * 2.0

	var start_pos = Vector2(100, 100)
	var hex_points = _get_pointy_top_hex_points(HEX_SIZE)

	# --- GENERATION ---
	for y in range(GRID_HEIGHT):
		var x_start = 0
		var x_count = 0

		# Standard GDScript Match Syntax
		match y:
			0, 6:
				x_start = 1
				x_count = 4
			1, 5:
				x_start = 1
				x_count = 5
			2, 4:
				x_start = 0
				x_count = 6
			3:
				x_start = 0
				x_count = 7

		for i in range(x_count):
			var x = x_start + i

			var x_pos = x * (hex_width + GAP)
			var y_pos = y * (hex_height * 0.75 + GAP)
			if y % 2 == 0:
				x_pos += (hex_width + GAP) / 2.0

			var final_pos = start_pos + Vector2(x_pos, y_pos)
			_create_map_node(x, y, final_pos, hex_points)

	# --- START GAME ---
	# Find the "Farthest Left" node to start on.
	var start_coords = Vector2i(0, 3)

	if grid_nodes.has(start_coords):
		# Force move to start without counting it as a 'move'
		_move_player_to(grid_nodes[start_coords], true)
	else:
		print("Error: Could not find start node at ", start_coords)

func _create_map_node(grid_x, grid_y, screen_pos, points):
	var node = MapNode.new()
	node.position = screen_pos
	node.name = "Hex_%d_%d" % [grid_x, grid_y]

	# The type is determined HERE, once, at generation. It will not change.
	var random_type = MapNode.NodeType.values().pick_random()
	var texture = _get_texture_for_type(random_type)

	node.setup(Vector2i(grid_x, grid_y), points, random_type, texture)
	node.node_clicked.connect(_on_node_clicked)

	add_child(node)
	grid_nodes[Vector2i(grid_x, grid_y)] = node

# --- GAMEPLAY LOGIC ---

func _on_node_clicked(target_node: MapNode):
	# 1. Check if we are already here
	if target_node == current_node:
		print("Already at this node.")
		return

	# 2. Check Adjacency (Must be neighbor, Distance = 1)
	if current_node != null:
		var dist = _get_hex_distance(current_node.grid_coords, target_node.grid_coords)
		if dist > 1:
			print("Too far! You can only move to adjacent nodes. Dist: ", dist)
			return

	# 3. Valid Move -> Execute
	_move_player_to(target_node)

func _move_player_to(target_node: MapNode, is_start: bool = false):
	current_node = target_node

	# Update State: The node we just landed on is now COMPLETED
	target_node.set_state(MapNode.NodeState.COMPLETED)

	if not is_start:
		total_moves += 1
		print("Moved to ", target_node.grid_coords, ". Total Moves: ", total_moves)

	# Apply Vision based on our new position
	_update_vision()

func _update_vision():
	# 0 = Blind, we see nothing new
	if vision_range <= 0:
		return

	var center_coords = current_node.grid_coords

	for node in grid_nodes.values():
		# If a node is already COMPLETED (Visited), we don't need to update it
		if node.state == MapNode.NodeState.COMPLETED:
			continue

		# Calculate distance from player to this node
		var dist = _get_hex_distance(center_coords, node.grid_coords)

		# If within range, reveal it (show icon)
		if dist <= vision_range:
			# Only reveal hidden nodes (don't mess with completed ones)
			if node.state == MapNode.NodeState.HIDDEN:
				node.set_state(MapNode.NodeState.REVEALED)

# --- UTILITIES ---

func _get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	var ac = _offset_to_cube(a)
	var bc = _offset_to_cube(b)
	return max(abs(ac.x - bc.x), abs(ac.y - bc.y), abs(ac.z - bc.z))

func _offset_to_cube(hex: Vector2i) -> Vector3i:
	# "Even-R" layout conversion
	var q = hex.x - (hex.y + (hex.y & 1)) / 2
	var r = hex.y
	var s = -q - r
	return Vector3i(q, r, s)

func _get_texture_for_type(type: MapNode.NodeType) -> Texture2D:
	match type:
		MapNode.NodeType.COMBAT: return icon_combat
		MapNode.NodeType.ELITE: return icon_elite
		MapNode.NodeType.BOSS: return icon_boss
		MapNode.NodeType.REWARD: return icon_reward
		MapNode.NodeType.EVENT: return icon_event
	return null

func _get_pointy_top_hex_points(size: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(6):
		var angle_deg = 30 + (60 * i)
		var angle_rad = deg_to_rad(angle_deg)
		pts.append(Vector2(size * cos(angle_rad), size * sin(angle_rad)))
	return pts
