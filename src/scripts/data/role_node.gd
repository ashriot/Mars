extends Resource
class_name RoleNode

enum RewardType { STAT, ACTION, SHIFT_ACTION, PASSIVE, EMPTY }

# --- REWARD DATA ---
@export var type: RewardType = RewardType.STAT
@export var stat_type: ActorStats.Stats
@export var stat_value: int = 0
@export var action_slot_index: int = -1

@export var left_node: RoleNode
@export var right_node: RoleNode
@export var child_node: RoleNode

# --- RUNTIME DATA ---
var generated_id: String = ""
var calculated_xp_cost: int = 0
var rank: int = 0

func initialize_tree(role_prefix: String, parent_suffix: String, current_rank: int, is_spine_path: bool):
	self.rank = current_rank
	self.generated_id = "%s_%s" % [role_prefix, parent_suffix]

	# Cost Logic
	var base_cost = 100 * current_rank
	if not is_spine_path:
		self.calculated_xp_cost = int(base_cost * 1.5)
	else:
		self.calculated_xp_cost = base_cost

	# --- RECURSION LOGIC ---

	# 1. Spine Child (Continues Down)
	if child_node:
		var suffix = parent_suffix
		if is_spine_path:
			# Main Spine: 1 -> 2
			suffix = str(current_rank + 1)
		else:
			# Side Chain: 21 -> 211
			suffix = parent_suffix + "1"

		child_node.initialize_tree(role_prefix, suffix, current_rank + 1, is_spine_path)

	# 2. Left Sibling (Branches Left)
	if left_node:
		# 2 -> 21 (Left)
		var suffix = parent_suffix + "1"
		# It is NO LONGER on the spine path
		left_node.initialize_tree(role_prefix, suffix, current_rank, false)

	# 3. Right Sibling (Branches Right)
	if right_node:
		# 2 -> 22 (Right)
		var suffix = parent_suffix + "2"
		right_node.initialize_tree(role_prefix, suffix, current_rank, false)
