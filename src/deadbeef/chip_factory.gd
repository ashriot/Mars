class_name ChipLibrary

# Enums matching your design doc
enum Rarity { COMMON, UNCOMMON, RARE, VERY_RARE, UNIQUE }
enum Protocol {
	NONE,
	# Tier 1
	BACKDOOR, FIREWALL,
	# Tier 2
	DECREMENT, FLANKING, INVERT, ROOTKIT, TRANSFER, VIRUS,
	# Tier 3
	AMPLIFY, CASCADE, DEADLOCK, MALLOC, OVERFLOW, REBOOT, RECURSIVE
}

# Direction Indices for convenience
const U = 0
const UR = 1
const DR = 2
const D = 3
const DL = 4
const UL = 5

# --- CONFIGURATION ---
const RARITY_DATA = {
	Rarity.COMMON:    { "base_rank": 1, "base_budget": 12 },
	Rarity.UNCOMMON:  { "base_rank": 2, "base_budget": 14 },
	Rarity.RARE:      { "base_rank": 3, "base_budget": 16 },
	Rarity.VERY_RARE: { "base_rank": 4, "base_budget": 18 },
	Rarity.UNIQUE:    { "base_rank": 5, "base_budget": 20 }
}

# Wall Cost is always 2 per wall
const WALL_COST = 2

# Protocol Costs (You can tweak these)
const PROTOCOL_COSTS = {
	Protocol.NONE: 0,
	Protocol.BACKDOOR: 1, Protocol.FIREWALL: 1,
	Protocol.DECREMENT: 2, Protocol.FLANKING: 2, Protocol.INVERT: 2,
	Protocol.ROOTKIT: 2, Protocol.TRANSFER: 2, Protocol.VIRUS: 2,
	Protocol.AMPLIFY: 3, Protocol.CASCADE: 3, Protocol.DEADLOCK: 3,
	Protocol.MALLOC: 3, Protocol.OVERFLOW: 3, Protocol.REBOOT: 3, Protocol.RECURSIVE: 3
}

# --- UNIT DEFINITIONS ---
# This is your "Deck" of defined units.
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
	"X-Strike":  { "rarity": Rarity.UNCOMMON, "walls": [UL, UR, DR, DL], "proto": Protocol.NONE },
	"Arc L":     { "rarity": Rarity.UNCOMMON, "walls": [DL, UL, U], "proto": Protocol.NONE },
	"Arc R":     { "rarity": Rarity.UNCOMMON, "walls": [U, UR, DR], "proto": Protocol.NONE },
	"Railgun":   { "rarity": Rarity.UNCOMMON, "walls": [U], "proto": Protocol.NONE },
	"Gunner U":  { "rarity": Rarity.UNCOMMON, "walls": [UL, UR], "proto": Protocol.NONE },
	"Gunner D":  { "rarity": Rarity.UNCOMMON, "walls": [DR, DL], "proto": Protocol.NONE }
}

# --- GENERATOR ---
static func create_chip_data(name: String, target_rank: int = -1) -> Dictionary:
	if not BLUEPRINTS.has(name):
		push_error("ChipLibrary: Unknown Blueprint '%s'" % name)
		return {}

	var bp = BLUEPRINTS[name]
	var rarity_info = RARITY_DATA[bp.rarity]

	# 1. Determine Rank (Default to base rank if not specified)
	var rank = target_rank
	if rank < rarity_info.base_rank:
		rank = rarity_info.base_rank

	# 2. Calculate Total Budget
	# Budget = Base + (RankIncreases)
	var budget = rarity_info.base_budget + (rank - rarity_info.base_rank)

	# 3. Calculate Costs
	var wall_count = bp.walls.size()
	var wall_deduction = wall_count * WALL_COST
	var proto_deduction = PROTOCOL_COSTS.get(bp.proto, 0)

	# 4. Calculate Kernel
	var final_kernel = budget - wall_deduction - proto_deduction

	# Ensure non-negative kernel (though your design generally prevents this)
	final_kernel = max(0, final_kernel)

	# 5. Format Wall Array (Indices to Booleans)
	var wall_bools = [false, false, false, false, false, false]
	for dir in bp.walls:
		wall_bools[dir] = true

	# Return the Data Packet required by GamePiece.setup()
	return {
		"name": name,
		"rarity": bp.rarity,
		"rank": rank,
		"kernel": final_kernel,
		"walls": wall_bools,
		"protocol": bp.proto
	}

static func get_random_blueprint_name() -> String:
	return BLUEPRINTS.keys().pick_random()
