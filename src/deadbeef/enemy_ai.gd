class_name EnemyAI

const OFFENSE_WEIGHT = 10.0
const DEFENSE_WALL_BONUS = 2.0
const VULNERABILITY_PENALTY = 5.0

const PROTO_BONUS_KILL = 3.0
const PROTO_BONUS_ADJACENT_FRIEND = 3.0
const PROTO_BONUS_ADJACENT_ENEMY = 2.0
const PROTO_BONUS_OPEN_SPACE = 1.5

static func get_best_move(board_manager: Control, ai_player_id: int, difficulty: int) -> Dictionary:
	var grid = board_manager.grid_chips
	var hand_container = board_manager.chip_hand_p2 if ai_player_id == 1 else board_manager.chip_hand_p1
	var hand_pieces = hand_container.get_children()

	var possible_moves = []

	for chip in grid.values():
		if chip.state != HexChip.ChipState.EMPTY: continue

		for i in range(hand_pieces.size()):
			var piece = hand_pieces[i]
			var score = _evaluate_move(chip, piece, grid, ai_player_id, board_manager)

			possible_moves.append({
				"chip": chip,
				"piece_index": i,
				"score": score
			})

	if possible_moves.is_empty(): return {}

	possible_moves.sort_custom(func(a, b): return a.score > b.score)

	if difficulty >= 2: return possible_moves[0]
	elif difficulty == 1:
		var pool_size = min(3, possible_moves.size())
		return possible_moves.slice(0, pool_size).pick_random()
	else:
		var pool_size = max(1, int(possible_moves.size() / 2.0))
		return possible_moves.slice(0, pool_size).pick_random()

static func _evaluate_move(target_chip: HexChip, piece: GamePiece, grid: Dictionary, my_id: int, manager) -> float:
	var score = 0.0
	var proto = piece.protocol
	var P = ChipLibrary.Protocol

	# Pack Data for Logic
	var my_data = {
		"atk": piece.atk_value,
		"def": piece.def_value,
		"rank": piece.rank,
		"protocol": piece.protocol
	}

	var neighbors = manager._get_neighbors_with_direction(target_chip.grid_coords)

	for entry in neighbors:
		var dir = entry.dir
		var neighbor_chip = entry.chip

		if neighbor_chip.state == HexChip.ChipState.OCCUPIED:
			var neighbor_piece = neighbor_chip.current_piece

			# --- ENEMY ---
			if neighbor_piece.owner_id != my_id:
				if proto == P.DECREMENT: score += PROTO_BONUS_ADJACENT_ENEMY

				# Can we attack?
				if piece.walls[dir]:
					var opp_dir = (dir + 3) % 6
					var enemy_has_wall = neighbor_piece.walls[opp_dir]
					var flip_success = false

					if not ProtocolLogic.can_be_flipped(neighbor_chip):
						flip_success = false # Deadlock
					elif not enemy_has_wall:
						flip_success = true # Auto Win
					else:
						# CLASH SIMULATION using Shared Logic
						var enemy_data = {
							"atk": neighbor_piece.atk_value,
							"def": neighbor_piece.def_value,
							"rank": neighbor_piece.rank,
							"protocol": neighbor_piece.protocol
						}

						if ProtocolLogic.resolve_clash(my_data, enemy_data):
							flip_success = true

					if flip_success:
						score += OFFENSE_WEIGHT
						if proto == P.VIRUS or proto == P.TRANSFER or proto == P.CASCADE:
							score += PROTO_BONUS_KILL
				else:
					# Exposed side facing enemy
					score -= 1.0

			# --- FRIEND ---
			else:
				score += 0.5
				if proto == P.AMPLIFY or proto == P.FLANKING:
					score += PROTO_BONUS_ADJACENT_FRIEND

		# --- EMPTY ---
		else:
			if proto == P.MALLOC: score += PROTO_BONUS_OPEN_SPACE
			# Defensive Check: Don't expose weak sides to empty space
			if not piece.walls[dir]:
				if proto == P.DEADLOCK: score -= (VULNERABILITY_PENALTY * 0.2)
				else: score -= VULNERABILITY_PENALTY

	return score
