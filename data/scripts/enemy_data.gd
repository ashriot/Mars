extends Resource
class_name EnemyData

enum AIPattern { LOOP, RANDOM, SETUP }

@export var portrait: Texture
@export var stat_ranks: EnemyStatRanks
@export var action_deck: Array[Action]
@export var ai_script_indices: Array[int]
@export var ai_pattern: AIPattern = AIPattern.LOOP

var stats: ActorStats:
	get: return _calculate_stats()

func _calculate_stats() -> ActorStats:
	var lv = stat_ranks.level
	var scalar = 1 + float(1 + (lv / 2)) / 10
	var actor_stats = ActorStats.new()
	actor_stats.actor_name = stat_ranks.actor_name
	actor_stats.max_hp = int((lv + 5) * (stat_ranks.max_hp + 5) * (5 + float(lv * 0.8)))
	actor_stats.guard = int(lv / 6) + stat_ranks.guard + 2
	actor_stats.attack = int((lv + 5) * (stat_ranks.attack + 3) * scalar)
	actor_stats.psyche = int((lv + 5) * (stat_ranks.attack + 3) * scalar)
	actor_stats.overload = int((lv + 5) * (stat_ranks.attack + 3) * scalar)
	actor_stats.speed = int((lv + 5) * (stat_ranks.attack + 3) * scalar)
	actor_stats.precision = int(lv / 2 ) + stat_ranks.precision * 5
	actor_stats.kinetic_defense =  5 + stat_ranks.kinetic_defense * 15
	actor_stats.energy_defense = stat_ranks.energy_defense * 20 - 10
	return actor_stats

# (lv + 5) * (stat_ranks.psyche + 5) OLD FORMULA
