extends Resource
class_name RankReward

enum RewardType {
	ACTION,           # Unlock a new action
	PASSIVE,          # Unlock passive ability
	SHIFT,            # Unlock shift action
	UPGRADE_CHOICE,   # Choose an upgrade for an action
	PERK_CHOICE,      # Choose a role perk
	STAT_BONUS        # Flat stat increase
}

@export var rank: int
@export var reward_type: RewardType
@export var action: Action  # If unlocking an action
@export var stat_bonus_type: ActorStats.Stats  # If stat bonus
@export var stat_bonus_amount: int = 0  # Amount to add
@export var upgrade_options: Array[ActionUpgrade] = []  # If upgrade choice
@export_multiline var display_text: String = ""  # e.g., "Choose an upgrade for Double Tap"
