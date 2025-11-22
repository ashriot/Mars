extends Control

# --- Board Configuration ---
@export var map_radius: int = 2
@export var hex_size: float = 200.0
@export var gap: float = 5.0

# --- Rules Configuration ---
@export var max_chain_depth: int = -1
const MAX_CHIPS_PER_PLAYER = 10

# --- AI Settings ---
@export_enum("Easy", "Medium", "Hard") var ai_difficulty: int = 1
@export var ai_delay: float = 1.0

# --- Assets ---
@export var chip_scene: PackedScene
@export var game_piece_scene: PackedScene
@export var test_unit_texture: Texture2D

# --- UI References ---
@onready var chip_hand_p1: Container = $ChipHandP1
@onready var chip_hand_p2: Container = $ChipHandP2
@onready var score_p1_label: Label = $ScoreP1
@onready var score_p2_label: Label = $ScoreP2

# --- Internal Data ---
var hex_width: float
var hex_height: float
var grid_chips = {}
var current_player: int = 0
var is_processing_turn: bool = false

var p1_chips_created: int = 0
var p2_chips_created: int = 0
var selected_piece: GamePiece = null

enum Dir { U=0, UR=1, DR=2, D=3, DL=4, UL=5 }

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	generate_board()
	_start_game()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		generate_board()
		_start_game()

func generate_board():
	print("Generating DEADBEEF Board...")
	hex_width = hex_size
	hex_height = hex_size

	if not chip_scene or not game_piece_scene:
		print("Error: Assign Scenes!")
		return

	for child in get_children():
		if child is HexChip: child.queue_free()
	grid_chips.clear()

	var screen_center = size / 2.0

	for q in range(-map_radius, map_radius + 1):
		var r1 = max(-map_radius, -q - map_radius)
		var r2 = min(map_radius, -q + map_radius)

		for r in range(r1, r2 + 1):
			var col = q
			var row = r + (q - (q & 1)) / 2

			var x_pos = col * (hex_width * 0.75 + gap)
			var y_pos = row * (hex_height * 0.95 + gap)
			if col % 2 != 0: y_pos += (hex_height + gap) / 2.0

			var final_pos = screen_center + Vector2(x_pos, y_pos)
			var size_vec = Vector2(hex_width, hex_height)

			_create_chip(col, row, final_pos, size_vec)

func _create_chip(grid_x, grid_y, screen_pos, size_vec):
	var chip = chip_scene.instantiate()
	add_child(chip)
	chip.position = screen_pos - (size_vec / 2.0)
	chip.name = "Chip_%d_%d" % [grid_x, grid_y]
	chip.setup(Vector2i(grid_x, grid_y), size_vec)
	chip.chip_interaction.connect(_on_chip_interaction)
	grid_chips[Vector2i(grid_x, grid_y)] = chip

# --- GAME LOOP ---

func _start_game():
	current_player = 0
	is_processing_turn = false
	p1_chips_created = 0
	p2_chips_created = 0
	selected_piece = null

	for child in chip_hand_p1.get_children(): child.queue_free()
	for child in chip_hand_p2.get_children(): child.queue_free()

	for i in range(5):
		_draw_card_to_hand(chip_hand_p1, 0, false)
		_draw_card_to_hand(chip_hand_p2, 1, true)

	_update_scores()

func _draw_card_to_hand(container: Container, owner_id: int, is_hidden: bool):
	if not test_unit_texture: return

	if owner_id == 0:
		if p1_chips_created >= MAX_CHIPS_PER_PLAYER: return
		p1_chips_created += 1
	else:
		if p2_chips_created >= MAX_CHIPS_PER_PLAYER: return
		p2_chips_created += 1

	var random_name = ChipLibrary.get_random_blueprint_name()
	var unit_data = ChipLibrary.create_chip_data(random_name)
	unit_data["texture"] = test_unit_texture

	var piece = game_piece_scene.instantiate()
	container.add_child(piece)
	piece.setup(unit_data, owner_id, Vector2(200, 200))
	piece.piece_selected.connect(_on_piece_selected)

	if is_hidden:
		piece.set_face_down(true)

# --- INTERACTION ---

func _on_piece_selected(piece: GamePiece):
	if is_processing_turn or piece.owner_id != current_player: return
	if selected_piece and selected_piece != piece: selected_piece.set_selected(false)
	selected_piece = piece
	selected_piece.set_selected(true)

func _on_chip_interaction(chip: HexChip, dropped_piece: GamePiece):
	if chip.state == HexChip.ChipState.OCCUPIED or is_processing_turn or current_player == 1: return
	var piece_to_play = null
	if dropped_piece:
		if dropped_piece.owner_id == current_player: piece_to_play = dropped_piece
	elif selected_piece:
		piece_to_play = selected_piece

	if piece_to_play:
		if selected_piece == piece_to_play:
			selected_piece.set_selected(false)
			selected_piece = null
		_play_turn(chip, piece_to_play)

func _play_turn(target_chip: HexChip, piece_to_play: GamePiece):
	is_processing_turn = true

	var hand_container = piece_to_play.get_parent()
	hand_container.remove_child(piece_to_play)

	piece_to_play.custom_minimum_size = target_chip.size
	piece_to_play.size = target_chip.size
	piece_to_play.pivot_offset = target_chip.size / 2.0
	piece_to_play.owner_id = current_player
	piece_to_play.set_face_down(false)
	piece_to_play._update_owner_color()

	target_chip.add_piece(piece_to_play)
	print("Player %d placed on %s" % [current_player, target_chip.grid_coords])

	# 1. TRIGGER ON PLACE PROTOCOLS
	ProtocolLogic.on_place(target_chip, self)

	# 2. RESOLVE COMBAT
	_resolve_combat_chain(target_chip)

	var is_p2 = (current_player == 1)
	_draw_card_to_hand(hand_container, current_player, is_p2)

	current_player = 1 - current_player
	_update_scores()
	is_processing_turn = false

	if current_player == 1:
		_start_enemy_turn()

# --- AI LOGIC ---

func _start_enemy_turn():
	is_processing_turn = true
	await get_tree().create_timer(ai_delay).timeout
	var move = EnemyAI.get_best_move(self, 1, ai_difficulty)
	if move.is_empty():
		print("AI has no valid moves!")
		is_processing_turn = false
		return
	var target_chip = move.chip
	var card_index = move.piece_index
	var piece = chip_hand_p2.get_child(card_index)
	_play_turn(target_chip, piece)

# --- COMBAT LOGIC ---

func _resolve_combat_chain(start_chip: HexChip):
	var process_queue = [{ "chip": start_chip, "depth": 0 }]
	var processed_in_chain = {}

	while process_queue.size() > 0:
		var current_item = process_queue.pop_front()
		var attacker_chip = current_item.chip
		var current_depth = current_item.depth
		processed_in_chain[attacker_chip] = true

		var attacker_piece = attacker_chip.current_piece
		var neighbors = _get_neighbors_with_direction(attacker_chip.grid_coords)

		# Data packet for Protocol Logic lookups
		var att_data = {
			"kernel": attacker_piece.kernel_value,
			"rank": attacker_piece.rank,
			"protocol": attacker_piece.protocol
		}

		for entry in neighbors:
			var dir_index = entry.dir
			var defender_chip = entry.chip

			if defender_chip.state == HexChip.ChipState.EMPTY: continue
			var defender_piece = defender_chip.current_piece
			if defender_piece.owner_id == attacker_piece.owner_id: continue

			# ATTACK RESOLUTION
			if not attacker_piece.walls[dir_index]:
				continue

			var opposite_dir = (dir_index + 3) % 6
			var has_defender_wall = defender_piece.walls[opposite_dir]

			# Check for Deadlock
			if not ProtocolLogic.can_be_flipped(defender_chip):
				print("Attack blocked by Deadlock")
				continue

			var flip_success = false

			if not has_defender_wall:
				flip_success = true
				print("Auto-Win vs ", defender_chip.grid_coords)
			else:
				# CLASH!
				# Get Protocol Bonuses
				var def_data = {
					"kernel": defender_piece.kernel_value,
					"rank": defender_piece.rank,
					"protocol": defender_piece.protocol
				}

				var att_bonus = ProtocolLogic.get_attack_bonus(att_data, def_data)
				var def_bonus = ProtocolLogic.get_defense_bonus(def_data, att_data)

				var final_att = attacker_piece.kernel_value + att_bonus
				var final_def = defender_piece.kernel_value + def_bonus

				print("Clash! Att: %d vs Def: %d" % [final_att, final_def])

				if final_att > final_def:
					flip_success = true

			if flip_success:
				defender_chip.flip_piece()

				# Trigger Flip Protocols (Transfer, Virus, etc)
				ProtocolLogic.on_flip_success(attacker_chip, defender_chip)

				if not processed_in_chain.has(defender_chip):
					if max_chain_depth == -1 or current_depth < max_chain_depth:
						process_queue.append({ "chip": defender_chip, "depth": current_depth + 1 })

func _update_scores():
	var p1_score = 0
	var p2_score = 0
	for chip in grid_chips.values():
		if chip.state == HexChip.ChipState.OCCUPIED and chip.current_piece:
			if chip.current_piece.owner_id == 0: p1_score += 1
			else: p2_score += 1
	score_p1_label.text = "P1: %d" % p1_score
	score_p2_label.text = "P2: %d" % p2_score

func _get_neighbors_with_direction(coords: Vector2i) -> Array:
	var list = []
	var offsets = _get_flat_top_offsets(coords.x)
	for dir_i in range(6):
		var neighbor_coords = coords + offsets[dir_i]
		if grid_chips.has(neighbor_coords):
			list.append({ "chip": grid_chips[neighbor_coords], "dir": dir_i })
	return list

func _get_neighbors(coords: Vector2i) -> Array:
	var list = []
	var offsets = _get_flat_top_offsets(coords.x)
	for off in offsets:
		var n = coords + off
		if grid_chips.has(n): list.append(grid_chips[n])
	return list

func _get_flat_top_offsets(col: int) -> Array:
	if col % 2 == 0:
		return [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
	else:
		return [Vector2i(0, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]
