# RoleProgression.gd
extends Resource
class_name RoleProgression

@export var role_id: String  # e.g., "asher_gunslinger"
@export var current_rank: int = 0
@export var current_xp: int = 0
@export var selected_upgrades: Dictionary = {}  # rank -> upgrade_choice
@export var selected_perks: Array[String] = []

# Stat bonuses earned from ranking up THIS role
@export var stat_bonuses: Dictionary = {
	ActorStats.Stats.HP: 0,
	ActorStats.Stats.GRD: 0,
	ActorStats.Stats.ATK: 0,
	ActorStats.Stats.PSY: 0,
	ActorStats.Stats.OVR: 0,
	ActorStats.Stats.SPD: 0,
	ActorStats.Stats.PRC: 0,
	ActorStats.Stats.KIN_DEF: 0,
	ActorStats.Stats.NRG_DEF: 0,
}

func xp_needed_for_next_rank() -> int:
	if current_rank >= 30:
		return 0  # Max rank
	if current_rank < 15:
		return (current_rank + 1) * 100
	else:
		return 1500  # Flat cost after rank 15

func can_rank_up(story_cap: int) -> bool:
	return current_rank < story_cap and current_xp >= xp_needed_for_next_rank()

func add_xp(amount: int) -> bool:
	current_xp += amount
	return current_xp >= xp_needed_for_next_rank()

func rank_up(reward: RankReward):
	current_rank += 1
	current_xp -= xp_needed_for_next_rank()

	# Apply stat bonus if this rank grants one
	if reward.stat_bonus_type != null:
		stat_bonuses[reward.stat_bonus_type] += reward.stat_bonus_amount
