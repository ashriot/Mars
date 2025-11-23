class_name ProtocolLogic

const P = ChipLibrary.Protocol

# --- COMBAT RESOLUTION (Single Source of Truth) ---
static func resolve_clash(att_data: Dictionary, def_data: Dictionary) -> bool:

	# 1. Determine Attacker's Power
	var attack_power = att_data.atk

	# FIREWALL: "Attacks using your DEF stat instead of your ATK"
	if att_data.protocol == P.FIREWALL:
		attack_power = att_data.def

	# 2. Determine Defender's Resistance
	var defense_power = def_data.def

	# BACKDOOR: "Attacks the enemy's ATK stat instead of their DEF"
	if att_data.protocol == P.BACKDOOR:
		defense_power = def_data.atk

	# 3. Rootkit Handling
	# If Attacker has Rootkit, they might ignore specific defense bonuses
	# (Since we removed wall bonuses, this currently does nothing,
	# but this is where you'd bypass buffs if you add them back).

	return attack_power > defense_power

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
						piece.modify_stats(-1)
		P.AMPLIFY:
			var neighbors = board_manager._get_neighbors(chip.grid_coords)
			for n in neighbors:
				if n.state == HexChip.ChipState.OCCUPIED:
					var piece = n.current_piece
					if piece.owner_id == chip.current_piece.owner_id:
						piece.modify_stats(1)
		P.MALLOC:
			var neighbors = board_manager._get_neighbors(chip.grid_coords)
			var empty_count = 0
			for n in neighbors:
				if n.state == HexChip.ChipState.EMPTY:
					empty_count += 1
			if empty_count > 0:
				chip.current_piece.modify_stats(empty_count)

static func on_flip_success(attacker_chip: HexChip, defender_chip: HexChip):
	var att_piece = attacker_chip.current_piece
	var def_piece = defender_chip.current_piece
	var proto = att_piece.protocol

	match proto:
		P.TRANSFER:
			att_piece.modify_stats(1)
			def_piece.modify_stats(-1)
		P.VIRUS:
			def_piece.modify_stats(-1)
		P.CASCADE:
			att_piece.modify_stats(1)

static func can_be_flipped(defender_chip: HexChip) -> bool:
	var piece = defender_chip.current_piece
	if piece.protocol == P.DEADLOCK:
		return false
	return true

static func on_turn_start(grid: Dictionary, current_player: int):
	for chip in grid.values():
		if chip.state == HexChip.ChipState.OCCUPIED:
			var piece = chip.current_piece
			if piece.protocol == P.REBOOT:
				if piece.original_owner_id == current_player:
					if piece.owner_id != current_player:
						chip.flip_piece()
