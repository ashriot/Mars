class_name EnemyAI

const OFFENSE_WEIGHT = 10.0 # Points per enemy flipped
const DEFENSE_WALL_BONUS = 2.0 # Points for having a wall facing an enemy
const VULNERABILITY_PENALTY = 5.0 # Penalty for exposing a no-wall side to an empty slot

# Protocol Specific Weights
const PROTO_BONUS_KILL = 3.0 # Bonus for flipping if we have Virus/Transfer/Cascade
const PROTO_BONUS_ADJACENT_FRIEND = 3.0 # Bonus per friend for Amplify/Flanking
const PROTO_BONUS_ADJACENT_ENEMY = 2.0 # Bonus per enemy for Decrement
const PROTO_BONUS_OPEN_SPACE = 1.5 # Bonus per empty neighbor for Malloc

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
	if difficulty >= 2:
		# HARD: Best move
		return possible_moves[0]
	elif difficulty == 1:
		# MEDIUM: Random top 3
		var pool_size = min(3, possible_moves.size())
		return possible_moves.slice(0, pool_size).pick_random()
	else:
		# EASY: Random top 50%
		var pool_size = max(1, int(possible_moves.size() / 2.0))
		return possible_moves.slice(0, pool_size).pick_random()

static func _evaluate_move(target_chip: HexChip, piece: GamePiece, grid: Dictionary, my_id: int, manager) -> float:
	var score = 0.0
	var proto = piece.protocol
	var P = ChipLibrary.Protocol

	# Create Data Packet for Protocol Logic (Simulation)
	var my_data = {
		"kernel": piece.kernel_value,
		"rank": piece.rank,
		"protocol": piece.protocol
	}

	# Get neighbors and their relative directions
	var neighbors = manager._get_neighbors_with_direction(target_chip.grid_coords)

	for entry in neighbors:
		var dir = entry.dir
		var neighbor_chip = entry.chip

		# CASE A: Neighbor is Occupied
		if neighbor_chip.state == HexChip.ChipState.OCCUPIED:
			var neighbor_piece = neighbor_chip.current_piece

			# --- ENEMY NEIGHBOR ---
			if neighbor_piece.owner_id != my_id:

				# 1. Protocol: Decrement likes enemies
				if proto == P.DECREMENT:
					score += PROTO_BONUS_ADJACENT_ENEMY

				# 2. Can we flip it?
				if piece.walls[dir]:
					var opp_dir = (dir + 3) % 6
					var enemy_has_wall = neighbor_piece.walls[opp_dir]
					var flip_success = false

					if not enemy_has_wall:
						flip_success = true # Auto-win
					else:
						# SIMULATE COMBAT MATH (Including Backdoor/Firewall/Rootkit)
						var enemy_data = {
							"kernel": neighbor_piece.kernel_value,
							"rank": neighbor_piece.rank,
							"protocol": neighbor_piece.protocol
						}

						var att_bonus = ProtocolLogic.get_attack_bonus(my_data, enemy_data)
						var def_bonus = ProtocolLogic.get_defense_bonus(enemy_data, my_data)

						var my_power = piece.kernel_value + att_bonus
						var enemy_power = neighbor_piece.kernel_value + def_bonus

						if my_power > enemy_power:
							flip_success = true

					if flip_success:
						score += OFFENSE_WEIGHT

						# Protocol: On-Flip Bonuses
						if proto == P.VIRUS or proto == P.TRANSFER or proto == P.CASCADE:
							score += PROTO_BONUS_KILL
				else:
					# No wall facing enemy? That's slightly risky (they might flip us back next turn)
					score -= 1.0

			# --- FRIENDLY NEIGHBOR ---
			else:
				# Standard clustering bonus
				score += 0.5

				# Protocol: Buffers like friends
				if proto == P.AMPLIFY or proto == P.FLANKING:
					score += PROTO_BONUS_ADJACENT_FRIEND

		# CASE B: Neighbor is Empty
		else:
			# Protocol: Malloc likes empty space
			if proto == P.MALLOC:
				score += PROTO_BONUS_OPEN_SPACE

			# Defense Check: Are we exposing a weak side?
			if not piece.walls[dir]:
				# If we are Deadlocked, we don't care about vulnerability as much (can't be flipped)
				if proto == P.DEADLOCK:
					score -= (VULNERABILITY_PENALTY * 0.2) # Reduced penalty
				else:
					score -= VULNERABILITY_PENALTY

	return score
