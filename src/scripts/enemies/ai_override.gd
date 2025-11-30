extends Resource
class_name AIOverride

enum PriorityType {
	HEALTH_BELOW_50,
	HEALTH_BELOW_25,
	WHEN_SELF_BREACHED,
	WHEN_ALLY_BREACHED,
	WHEN_PLAYER_BREACHED,
	ALLY_HP_LOW,
	HAS_BUFF,
	FIRST_TURN
}

@export var priority: PriorityType
@export var action_to_use: Action
@export var probability: float = 1.0 # 1.0 = Always do it if condition met
@export var one_time_use: bool = false # If true, only fires once per battle

# Use this for HAS_BUFF (e.g. "Enraged")
@export var context_value: String = ""
