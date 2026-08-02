extends Resource
class_name EnemyData

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

@export var abilities: Array[EnemyAbility] = []
@export var recover_action: Action = preload(
	"res://data/enemies/actions/recover_breach.tres"
)

var stats: ActorStats

func calculate_stats():
	stats = ActorStats.new()

	stats.actor_name = enemy_name
	stats.max_hp = int(_calc_stat(hp_rank, 5, 15) * 5)
	stats.starting_guard = int(level / 8) + guard_rank
	stats.attack = _calc_stat(attack_rank)
	stats.psyche = _calc_stat(psyche_rank)
	stats.speed = _calc_stat(speed_rank)
	stats.overload = _calc_stat(overload_rank, 0) * 3
	stats.aim = int(level / 2) + aim_rank * 5
	stats.precision = _calc_stat(aim_rank)
	stats.kinetic_defense = clampi(kinetic_defense_rank * 20 - 10, 0, 90)
	stats.energy_defense = clampi(energy_defense_rank * 20 - 10, 0, 90)

	#print(stats)

func _calc_stat(rank: int, rank_bonus: int = 5, scalar: int = 30) -> int:
	var multiplier = _get_multiplier()
	multiplier *= (1 + level / scalar)
	var value = int((rank + rank_bonus) * multiplier)
	return int(value)

func _get_multiplier() -> float:
	return (level + pow(level, 2) * 0.03) / 2 + 1.5
