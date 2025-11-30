extends Resource
class_name EnemyData

enum AIPattern { SEQUENCE, RANDOM }

@export var enemy_id: String = "trooper"
@export var enemy_name: String = "Trooper"
@export var level: int = 1
@export var portrait: Texture

# Stat ranks (1-10 scale for each stat)
@export var hp_rank: int = 5
@export var guard_rank: int = 3
@export var attack_rank: int = 5
@export var psyche_rank: int = 5
@export var overload_rank: int = 5
@export var speed_rank: int = 5
@export var aim_rank: int = 5
@export var kinetic_defense_rank: int = 5
@export var energy_defense_rank: int = 5

@export var ai_script_indices: Array[int]
@export var ai_pattern: AIPattern = AIPattern.SEQUENCE
@export var action_deck: Array[Action]
@export var ai_overrides: Array[AIOverride]

var stats: ActorStats

func calculate_stats():
	stats = ActorStats.new()

	stats.actor_name = enemy_name
	stats.max_hp = _calc_stat(hp_rank) * 5
	stats.starting_guard = int(level / 5) + guard_rank + 1
	stats.attack = _calc_stat(attack_rank)
	stats.psyche = _calc_stat(psyche_rank)
	stats.speed = _calc_stat(speed_rank)
	stats.overload = _calc_stat(overload_rank, 0) * 3
	stats.aim = int(level / 2) + aim_rank * 5
	stats.aim_dmg = _calc_stat(aim_rank)
	stats.kinetic_defense = kinetic_defense_rank * 20 - 10
	stats.energy_defense = energy_defense_rank * 20 - 10

	print(stats)

func _calc_stat(rank: int, rank_bonus: int = 5) -> int:
	var multiplier = _get_multiplier()
	var value = int((rank + rank_bonus) * multiplier)
	return int(value)

func _get_multiplier() -> int:
	return int(pow((level + 5), 2) * 0.048) * 2
