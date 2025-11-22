class_name EnemyAI

const OFFENSE_WEIGHT = 10.0 # Points per enemy flipped
const DEFENSE_WALL_BONUS = 2.0 # Points for having a wall facing an enemy
const VULNERABILITY_PENALTY = 5.0 # Penalty for exposing a no-wall side to an empty slot

# Returns a Dictionary: { "chip": HexChip, "piece_index": int }
static func get_best_move(board_manager: Control, ai_player_id: int, difficulty: int) -> Dictionary:
	var grid = board_manager.grid_chips
	var hand_container = board_manager.chip_hand_p2 if ai_player_id == 1 else board_manager.chip_hand_p1
	var hand_pieces = hand_container.get_children()

	var possible_moves = []

	# 1. Analyze every possible move (Slot x Card)
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

	if possible_moves.is_empty():
		return {}

	# 2. Sort by Score (Highest first)
	possible_moves.sort_custom(func(a, b): return a.score > b.score)

	# 3. Select based on Difficulty
	# 0 = Easy, 1 = Medium, 2 = Hard

	if difficulty >= 2:
		# HARD: Always pick the best
		return possible_moves[0]

	elif difficulty == 1:
		# MEDIUM: Pick random from top 3 (Human-like error)
		var pool_size = min(3, possible_moves.size())
		var pool = possible_moves.slice(0, pool_size)
		return pool.pick_random()

	else:
		# EASY: Pick random from the top 50% (Chaos)
		var pool_size = max(1, int(possible_moves.size() / 2.0))
		var pool = possible_moves.slice(0, pool_size)
		return pool.pick_random()

static func _evaluate_move(target_chip: HexChip, piece: GamePiece, grid: Dictionary, my_id: int, manager) -> float:
	var score = 0.0

	# Get neighbors and their relative directions
	var neighbors = manager._get_neighbors_with_direction(target_chip.grid_coords)

	for entry in neighbors:
		var dir = entry.dir
		var neighbor_chip = entry.chip

		# CASE A: Neighbor is Occupied
		if neighbor_chip.state == HexChip.ChipState.OCCUPIED:
			var neighbor_piece = neighbor_chip.current_piece

			# If Enemy...
			if neighbor_piece.owner_id != my_id:
				# Can we flip it?
				# 1. Do we have a wall?
				if piece.walls[dir]:
					var opp_dir = (dir + 3) % 6
					var enemy_has_wall = neighbor_piece.walls[opp_dir]

					# 2. Resolution
					if not enemy_has_wall:
						score += OFFENSE_WEIGHT # Auto-win
					elif piece.kernel_value > neighbor_piece.kernel_value:
						score += OFFENSE_WEIGHT # Kernel win
					# (Tie or Loss gives 0 points)

			# If Friendly...
			else:
				# Tiny bonus for clustering (optional)
				score += 0.5

		# CASE B: Neighbor is Empty
		else:
			# Defense Check: Are we exposing a weak side?
			if not piece.walls[dir]:
				score -= VULNERABILITY_PENALTY

	return score
