extends Resource
class_name RoleNode

const BASE_XP_COST: int = 10

enum RewardType { STAT, ACTION, SHIFT_ACTION, PASSIVE, EMPTY }

# --- REWARD DATA ---
@export var type: RewardType = RewardType.STAT

# For STAT rewards:
@export var stat_type: ActorStats.Stats
@export var stat_value: int = 0

# For ACTION rewards:
# 0=Bottom, 1=Right, 2=Left, 3=Top
# This now maps directly to RoleDefinition.actions[i]
@export var action_slot_index: int = -1

# --- CONNECTIONS ---
@export var next_nodes: Array[RoleNode]

# --- RUNTIME GENERATED DATA ---
var generated_id: String = ""
var calculated_xp_cost: int = 0
var rank: int = 0 # The "Depth" on the main spine

# This function recursively initializes this node and its children
func initialize_tree(role_prefix: String, parent_suffix: String, current_rank: int, is_spine_path: bool):
	self.rank = current_rank

	# 1. Generate ID Suffix
	# If this is the Root (passed in manually), it's just the suffix.
	# Otherwise, logic is handled by the parent loop below.
	var my_suffix = parent_suffix
	self.generated_id = "%s_%s" % [role_prefix, my_suffix]

	# 2. Calculate Cost
	var base_cost = BASE_XP_COST * current_rank

	# Side Node Tax: If we aren't on the spine, costs are 50% higher
	if not is_spine_path:
		self.calculated_xp_cost = int(base_cost * 1.5)
	else:
		self.calculated_xp_cost = base_cost

	# 3. Process Children
	for i in range(next_nodes.size()):
		var child = next_nodes[i]

		if i == 0:
			# --- PATH A: CONTINUATION (Index 0) ---
			if is_spine_path:
				# We are on the spine, continuing the spine.
				# ID: "1" -> "2"
				# Rank: Increases
				child.initialize_tree(role_prefix, str(current_rank + 1), current_rank + 1, true)
			else:
				# We are on a side path, continuing the side path.
				# ID: "41" -> "411"
				# Rank: Stays same (it's a sibling chain), or increases?
				# Usually side chains get more expensive as they go deep,
				# so let's treat depth as rank increase for cost purposes.
				child.initialize_tree(role_prefix, my_suffix + "1", current_rank + 1, false)
		else:
			# --- PATH B: BRANCHING (Index 1+) ---
			# We are branching OFF the current node.
			# ID: "4" -> "41", "42"
			# This marks the start of a side path.
			var branch_suffix = my_suffix + str(i)
			child.initialize_tree(role_prefix, branch_suffix, current_rank, false)
