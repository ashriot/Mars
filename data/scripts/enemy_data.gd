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
	var actor_stats = ActorStats.new()
	actor_stats.actor_name = stat_ranks.actor_name
	actor_stats.max_hp = (stat_ranks.level + 5) * (stat_ranks.max_hp + 5) * (5 + int(stat_ranks.level / 2))
	actor_stats.guard = int(stat_ranks.level / 6) + stat_ranks.guard + 2
	actor_stats.attack = (stat_ranks.level + 5) * (stat_ranks.attack + 5)
	actor_stats.psyche = (stat_ranks.level + 5) * (stat_ranks.psyche + 5)
	actor_stats.overload = (stat_ranks.level + 5) * (stat_ranks.overload + 5)
	actor_stats.speed = (stat_ranks.level + 5) * (stat_ranks.speed + 5)
	actor_stats.precision = 5 + stat_ranks.precision * 5
	actor_stats.kinetic_defense =  15 + stat_ranks.kinetic_defense * 15
	actor_stats.energy_defense = 15 + stat_ranks.energy_defense * 15
	return actor_stats
