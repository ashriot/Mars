extends Resource
class_name RoleNode

enum RewardType { STAT, ACTION, SHIFT_ACTION, PASSIVE, EMPTY }

# --- REWARD DATA ---
@export var type: RewardType = RewardType.STAT
@export var stat_type: ActorStats.Stats
@export var stat_value: int = 0
@export var unlock_resource: Resource # Action or Condition

# --- MAPPING ---
# 0=Bottom, 1=Right, 2=Left, 3=Top. -1 = Auto/Append
@export var action_slot_index: int = -1

# --- CONNECTIONS ---
@export var next_nodes: Array[RoleNode]

# --- RUNTIME GENERATED DATA ---
var generated_id: String = ""
var calculated_xp_cost: int = 0

# This function recursively initializes this node and its children
func initialize_tree(role_prefix: String, current_rank: int):
	# 1. Generate ID: "gun_atk_5"
	var type_str = "node"
	match type:
		RewardType.STAT:
			if stat_type < ActorStats.Stats.size():
				type_str = ActorStats.Stats.keys()[stat_type].to_lower()
		RewardType.ACTION: type_str = "act"
		RewardType.PASSIVE: type_str = "pas"

	# This ID is globally unique to the role (e.g. "gun_act_1")
	self.generated_id = "%s_%s_%d" % [role_prefix, type_str, current_rank]

	# 2. Generate Cost
	self.calculated_xp_cost = 100 + (current_rank * 50)

	# 3. Recurse
	for child in next_nodes:
		child.initialize_tree(role_prefix, current_rank + 1)
