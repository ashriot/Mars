extends Resource
class_name EnemyData

enum AIPattern { LOOP, RANDOM, SETUP }

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

@export var action_deck: Array[Action]
@export var ai_script_indices: Array[int]
@export var ai_pattern: AIPattern = AIPattern.LOOP

var stats: ActorStats

func calculate_stats() -> ActorStats:
	stats = ActorStats.new()
	var lv = level

	stats.actor_name = enemy_name
	stats.max_hp = _calc_stat(hp_rank, lv) * 5
	stats.starting_guard = int(lv / 6) + guard_rank + 2
	stats.attack = _calc_stat(attack_rank, lv)
	stats.psyche = _calc_stat(psyche_rank, lv)
	stats.overload = _calc_stat(overload_rank, lv)
	stats.speed = _calc_stat(speed_rank, lv)
	stats.aim = int(lv / 2) + aim_rank * 5
	stats.kinetic_defense = kinetic_defense_rank * 20 - 10
	stats.energy_defense = energy_defense_rank * 20 - 10

	return stats

func _calc_stat(rank: int, lv: int) -> int:
	var multiplier = 1.25 + ((lv + 5) ** 2) * 0.03
	var value = int((rank + 5) * multiplier * 2)
	return int(value)
