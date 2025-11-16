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
	var actor_stats = ActorStats.new()
	actor_stats.actor_name = stat_ranks.actor_name
	actor_stats.max_hp = _calc_stat(stat_ranks.max_hp) * 10
	actor_stats.guard = int(lv / 6) + stat_ranks.guard + 2
	actor_stats.attack = _calc_stat(stat_ranks.max_hp)
	actor_stats.psyche = _calc_stat(stat_ranks.max_hp)
	actor_stats.overload = _calc_stat(stat_ranks.max_hp)
	actor_stats.speed = _calc_stat(stat_ranks.max_hp)
	actor_stats.precision = int(lv / 2 ) + stat_ranks.precision * 5
	actor_stats.kinetic_defense = stat_ranks.kinetic_defense * 20 - 10
	actor_stats.energy_defense = stat_ranks.energy_defense * 20 - 10
	return actor_stats

# (lv + 5) * (stat_ranks + 5) OLD FORMULA

func _calc_stat(rank: int) -> int:
	var multiplier = 1.25 + ((stat_ranks.level + 5) ** 2) * 0.03
	# =INT($A$1*10+(B13*POW(Heroes!$U$1,1.2)))
	var value = stat_ranks.level * 10 + (rank * (multiplier * 2))
	return int(value)
