class_name ChipLibrary

enum Rarity { COMMON, UNCOMMON, RARE, VERY_RARE, UNIQUE }
enum Protocol {
	NONE,
	BACKDOOR, FIREWALL,
	DECREMENT, FLANKING, INVERT, ROOTKIT, TRANSFER, VIRUS,
	AMPLIFY, CASCADE, DEADLOCK, MALLOC, REBOOT, RECURSIVE
}

const U = 0
const UR = 1
const DR = 2
const D = 3
const DL = 4
const UL = 5

const PROTO_DESC = {
	Protocol.NONE: "No special protocol installed.",
	Protocol.BACKDOOR: "Backdoor: Attacks the enemy's ATK stat instead of their DEF.",
	Protocol.FIREWALL: "Firewall: Attacks using your DEF stat instead of your ATK.",
	Protocol.DECREMENT: "Decrement: On Place: Give -1 Stats to adjacent enemies.",
	Protocol.FLANKING: "Flanking: Gain +1 Stats for each adjacent friendly chip.",
	Protocol.INVERT: "Invert: Walls invert (On/Off) at the start of every turn.",
	Protocol.ROOTKIT: "Rootkit: Attacks ignore enemy Firewall bonuses.",
	Protocol.TRANSFER: "Transfer: When flipping an enemy, steal 1 Stat.",
	Protocol.VIRUS: "Virus: When flipping an enemy, give them -1 Stats permanently.",
	Protocol.AMPLIFY: "Amplify: On Place: Give +1 Stats to adjacent friendly chips.",
	Protocol.CASCADE: "Cascade: Gain +1 Stats for every chip flipped during placement.",
	Protocol.DEADLOCK: "Deadlock: This chip cannot be flipped by attacks.",
	Protocol.MALLOC: "Malloc: On Place: Gain +1 Stats for every adjacent empty hex.",
	Protocol.REBOOT: "Reboot: At the start of your turn, flips back to your color.",
	Protocol.RECURSIVE: "Recursive: Before being attacked, attacks first."
}

const RARITY_DATA = {
	Rarity.COMMON:    { "base_rank": 1, "base_budget": 12 },
	Rarity.UNCOMMON:  { "base_rank": 2, "base_budget": 14 },
	Rarity.RARE:      { "base_rank": 3, "base_budget": 16 },
	Rarity.VERY_RARE: { "base_rank": 4, "base_budget": 18 },
	Rarity.UNIQUE:    { "base_rank": 5, "base_budget": 20 }
}

const WALL_COST = 2

const PROTOCOL_COSTS = {
	Protocol.NONE: 0,
	Protocol.BACKDOOR: 1, Protocol.FIREWALL: 1,
	Protocol.DECREMENT: 2, Protocol.FLANKING: 2, Protocol.INVERT: 2,
	Protocol.ROOTKIT: 2, Protocol.TRANSFER: 2, Protocol.VIRUS: 2,
	Protocol.AMPLIFY: 3, Protocol.CASCADE: 3, Protocol.DEADLOCK: 3,
	Protocol.MALLOC: 3, Protocol.REBOOT: 3, Protocol.RECURSIVE: 3
}

const BLUEPRINTS = {
	# COMMON
	"Striker L": { "rarity": Rarity.COMMON, "walls": [U, UL], "proto": Protocol.NONE },
	"Striker R": { "rarity": Rarity.COMMON, "walls": [U, UR], "proto": Protocol.NONE },
	"Flanker L": { "rarity": Rarity.COMMON, "walls": [D, DL], "proto": Protocol.NONE },
	"Flanker R": { "rarity": Rarity.COMMON, "walls": [D, DR], "proto": Protocol.NONE },
	"Lancer":    { "rarity": Rarity.COMMON, "walls": [U, D],  "proto": Protocol.NONE },
	"Waller U":  { "rarity": Rarity.COMMON, "walls": [UL, U, UR], "proto": Protocol.NONE },
	"Waller D":  { "rarity": Rarity.COMMON, "walls": [DR, D, DL], "proto": Protocol.NONE },

	# UNCOMMON
	"X-Strike":     { "rarity": Rarity.UNCOMMON, "walls": [UL, UR, DR, DL], "proto": Protocol.NONE },
	"Arc L":        { "rarity": Rarity.UNCOMMON, "walls": [DL, UL, U], "proto": Protocol.NONE },
	"Arc R":        { "rarity": Rarity.UNCOMMON, "walls": [U, UR, DR], "proto": Protocol.NONE },
	"Railgun":      { "rarity": Rarity.UNCOMMON, "walls": [U], "proto": Protocol.NONE },
	"Gunner U":     { "rarity": Rarity.UNCOMMON, "walls": [UL, UR], "proto": Protocol.NONE },
	"Gunner D":     { "rarity": Rarity.UNCOMMON, "walls": [DR, DL], "proto": Protocol.NONE },
	"Y-Fork":       { "rarity": Rarity.UNCOMMON, "walls": [UL, U, UR], "proto": Protocol.NONE },
	"Inverse-Y":    { "rarity": Rarity.UNCOMMON, "walls": [DL, D, DR], "proto": Protocol.NONE },
	"Piercer L":    { "rarity": Rarity.UNCOMMON, "walls": [UL, UR, D], "proto": Protocol.NONE },
	"Piercer R":    { "rarity": Rarity.UNCOMMON, "walls": [U, DL, DR], "proto": Protocol.NONE },
	"Bulwark Line": { "rarity": Rarity.UNCOMMON, "walls": [UL, UR], "proto": Protocol.NONE },

	# RARE
	"Infiltrator": { "rarity": Rarity.RARE, "walls": [U, D], "proto": Protocol.BACKDOOR },
	"Bastion": { "rarity": Rarity.RARE, "walls": [UL, UR, DL, DR], "proto": Protocol.FIREWALL },
	"Corruptor": { "rarity": Rarity.RARE, "walls": [U, UR, UL], "proto": Protocol.DECREMENT },
	"Node Master": { "rarity": Rarity.RARE, "walls": [D, DL, DR], "proto": Protocol.AMPLIFY },
	"Scavenger": { "rarity": Rarity.RARE, "walls": [U, D], "proto": Protocol.MALLOC },
}

static func create_chip_data(name: String, requested_rank: int = -1) -> Dictionary:
	if not BLUEPRINTS.has(name):
		return {}

	var bp = BLUEPRINTS[name]
	var rarity_info = RARITY_DATA[bp.rarity]
	var base_rank = rarity_info.base_rank
	var actual_rank = base_rank
	if requested_rank != -1:
		actual_rank = clampi(requested_rank, base_rank, 5)

	var rank_difference = actual_rank - base_rank
	var budget = rarity_info.base_budget + rank_difference
	var wall_count = bp.walls.size()
	var stat_points = max(2, budget - (wall_count * WALL_COST) - PROTOCOL_COSTS.get(bp.proto, 0))

	# Random Stat Split
	var atk = 1
	var def = 1
	var remaining = stat_points - 2
	if remaining > 0:
		var add_to_atk = randi_range(0, remaining)
		atk += add_to_atk
		def += (remaining - add_to_atk)

	var wall_bools = [false, false, false, false, false, false]
	for dir in bp.walls: wall_bools[dir] = true

	return {
		"name": name,
		"rarity": bp.rarity,
		"rank": actual_rank,
		"atk": atk,
		"def": def,
		"walls": wall_bools,
		"protocol": bp.proto
	}

static func get_random_blueprint_name() -> String:
	return BLUEPRINTS.keys().pick_random()

# NEW: Helper to find a random chip of a specific rarity
static func get_random_blueprint_by_rarity(target_rarity: Rarity) -> String:
	var candidates = []
	for name in BLUEPRINTS.keys():
		if BLUEPRINTS[name].rarity == target_rarity:
			candidates.append(name)

	if candidates.is_empty():
		# Fallback if no chips of that rarity exist
		return get_random_blueprint_name()

	return candidates.pick_random()
