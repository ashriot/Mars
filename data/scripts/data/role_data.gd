extends Resource
class_name RoleData

@export var role_id: String = "gunslinger"
@export var role_name: String = "Gunslinger"
@export_multiline var description: String = ""
@export var icon: Texture
@export var color: Color

# Rank rewards define progression
@export var rank_rewards: Array[RankReward] = []

# Base actions (unlocked at specific ranks)
@export var shift_action: Action
@export var passive: Action
@export var actions: Array[Action]

func get_reward_at_rank(rank: int) -> RankReward:
	for reward in rank_rewards:
		if reward.rank == rank:
			return reward
	return null
