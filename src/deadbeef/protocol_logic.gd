class_name ProtocolLogic

# Uses the Enum from ChipLibrary for clean comparisons
const P = ChipLibrary.Protocol

# --- COMBAT MODIFIERS ---
static func get_attack_bonus(attacker_data: Dictionary, defender_data: Dictionary) -> int:
	var bonus = 0
	var rank = attacker_data.get("rank", 1)
	var proto = attacker_data.get("protocol", P.NONE)

	match proto:
		P.BACKDOOR:
			bonus += (rank - 2) * 2
		P.ROOTKIT:
			pass

	return bonus

static func get_defense_bonus(defender_data: Dictionary, attacker_data: Dictionary) -> int:
	var bonus = 0
	var rank = defender_data.get("rank", 1)
	var proto = defender_data.get("protocol", P.NONE)
	var attacker_proto = attacker_data.get("protocol", P.NONE)

	if attacker_proto == P.ROOTKIT and proto == P.FIREWALL:
		return 0

	match proto:
		P.FIREWALL:
			bonus += (rank - 2) * 2

	return bonus

# --- EVENT TRIGGERS ---

static func on_place(chip: HexChip, board_manager: Control):
	if not chip.current_piece: return
	var proto = chip.current_piece.protocol

	match proto:
		P.DECREMENT:
			var neighbors = board_manager._get_neighbors(chip.grid_coords)
			for n in neighbors:
				if n.state == HexChip.ChipState.OCCUPIED:
					var piece = n.current_piece
					if piece.owner_id != chip.current_piece.owner_id:
						piece.modify_kernel(-1)

		P.AMPLIFY:
			var neighbors = board_manager._get_neighbors(chip.grid_coords)
			for n in neighbors:
				if n.state == HexChip.ChipState.OCCUPIED:
					var piece = n.current_piece
					if piece.owner_id == chip.current_piece.owner_id:
						piece.modify_kernel(1)

		P.MALLOC:
			var neighbors = board_manager._get_neighbors(chip.grid_coords)
			var empty_count = 0
			for n in neighbors:
				if n.state == HexChip.ChipState.EMPTY:
					empty_count += 1

			if empty_count > 0:
				chip.current_piece.modify_kernel(empty_count)

static func on_flip_success(attacker_chip: HexChip, defender_chip: HexChip):
	var att_piece = attacker_chip.current_piece
	var def_piece = defender_chip.current_piece
	var proto = att_piece.protocol

	match proto:
		P.TRANSFER:
			att_piece.modify_kernel(1)
			def_piece.modify_kernel(-1)
		P.VIRUS:
			def_piece.modify_kernel(-1)
		P.CASCADE:
			att_piece.modify_kernel(1)

static func can_be_flipped(defender_chip: HexChip) -> bool:
	var piece = defender_chip.current_piece
	if piece.protocol == P.DEADLOCK:
		return false
	return true

# --- NEW: START OF TURN LOGIC ---
static func on_turn_start(grid: Dictionary, current_player: int):
	for chip in grid.values():
		if chip.state == HexChip.ChipState.OCCUPIED:
			var piece = chip.current_piece
			if piece.protocol == P.REBOOT:
				# If this chip ORIGINALLY belonged to the current player...
				if piece.original_owner_id == current_player:
					# ...but is currently owned by the enemy (was flipped)
					if piece.owner_id != current_player:
						# RECLAIM IT!
						chip.flip_piece()
						# Note: We generally don't trigger flip chains on passive effects
						# to avoid infinite loops or confusion at start of turn.

static func recalculate_dynamic_stats(grid: Dictionary):
	for chip in grid.values():
		if chip.state == HexChip.ChipState.OCCUPIED:
			var piece = chip.current_piece
			if piece.protocol == P.FLANKING:
				pass
