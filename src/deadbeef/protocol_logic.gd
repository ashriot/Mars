class_name ProtocolLogic

# Uses the Enum from ChipLibrary for clean comparisons
const P = ChipLibrary.Protocol

# --- COMBAT MODIFIERS ---
# Called when calculating Attack Strength
static func get_attack_bonus(attacker_data: Dictionary, defender_data: Dictionary) -> int:
	var bonus = 0
	var rank = attacker_data.get("rank", 1)
	var proto = attacker_data.get("protocol", P.NONE)

	match proto:
		P.BACKDOOR:
			# +2 at Rank 3, +4 at Rank 4, +6 at Rank 5
			bonus += (rank - 2) * 2

		P.ROOTKIT:
			# If defender has Firewall, we assume we are ignoring it.
			# Implementation detail: We might handle this by returning a value that cancels defense
			# OR the board manager checks is_rootkit before applying defense.
			pass

	return bonus

# Called when calculating Defense Strength
static func get_defense_bonus(defender_data: Dictionary, attacker_data: Dictionary) -> int:
	var bonus = 0
	var rank = defender_data.get("rank", 1)
	var proto = defender_data.get("protocol", P.NONE)
	var attacker_proto = attacker_data.get("protocol", P.NONE)

	# Rootkit bypasses Firewall
	if attacker_proto == P.ROOTKIT and proto == P.FIREWALL:
		return 0

	match proto:
		P.FIREWALL:
			# +2 at Rank 3, +4 at Rank 4, +6 at Rank 5
			bonus += (rank - 2) * 2

	return bonus

# --- EVENT TRIGGERS ---

# Triggered immediately after a chip is placed on the board
static func on_place(chip: HexChip, board_manager: Control):
	if not chip.current_piece: return
	var proto = chip.current_piece.protocol

	match proto:
		P.DECREMENT:
			# -1 Kernel to adjacent enemies
			var neighbors = board_manager._get_neighbors(chip.grid_coords)
			for n in neighbors:
				if n.state == HexChip.ChipState.OCCUPIED:
					var piece = n.current_piece
					if piece.owner_id != chip.current_piece.owner_id:
						piece.modify_kernel(-1)

		P.AMPLIFY:
			# +1 Kernel to adjacent friendlies
			var neighbors = board_manager._get_neighbors(chip.grid_coords)
			for n in neighbors:
				if n.state == HexChip.ChipState.OCCUPIED:
					var piece = n.current_piece
					if piece.owner_id == chip.current_piece.owner_id:
						piece.modify_kernel(1)

		P.MALLOC:
			# +1 Kernel for every EMPTY adjacent hex
			var neighbors = board_manager._get_neighbors(chip.grid_coords)
			var empty_count = 0
			for n in neighbors:
				if n.state == HexChip.ChipState.EMPTY:
					empty_count += 1

			if empty_count > 0:
				chip.current_piece.modify_kernel(empty_count)

# Triggered when 'attacker_chip' successfully flips 'defender_chip'
static func on_flip_success(attacker_chip: HexChip, defender_chip: HexChip):
	var att_piece = attacker_chip.current_piece
	var def_piece = defender_chip.current_piece
	var proto = att_piece.protocol

	match proto:
		P.TRANSFER:
			# Steal 1 stat
			att_piece.modify_kernel(1)
			def_piece.modify_kernel(-1)

		P.VIRUS:
			# Weaken enemy
			def_piece.modify_kernel(-1)

		P.CASCADE:
			# Grow stronger with momentum
			att_piece.modify_kernel(1)

# Triggered before combat resolution to see if flip is even possible
static func can_be_flipped(defender_chip: HexChip) -> bool:
	var piece = defender_chip.current_piece
	if piece.protocol == P.DEADLOCK:
		return false
	return true

# Triggered Start of Turn (For Reboot)
static func on_turn_start(grid: Dictionary, current_player: int):
	# Loop all chips to find Reboot protocols
	for chip in grid.values():
		if chip.state == HexChip.ChipState.OCCUPIED:
			var piece = chip.current_piece
			if piece.protocol == P.REBOOT:
				# If I don't own it, reclaim it!
				# Note: This implies Reboot chips remember their original owner.
				# For now, we assume the player who played it is the 'original' owner
				# stored in a variable we might need to add to GamePiece.
				pass

# Triggered for dynamic updates (Flanking)
static func recalculate_dynamic_stats(grid: Dictionary):
	for chip in grid.values():
		if chip.state == HexChip.ChipState.OCCUPIED:
			var piece = chip.current_piece
			if piece.protocol == P.FLANKING:
				# Reset to base? That requires storing base stats separately.
				# For simple implementation, we just calculate the buff:
				# This requires GamePiece to distinguish 'base_kernel' vs 'current_kernel'.
				pass
