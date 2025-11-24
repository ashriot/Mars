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

func calculate_stats():
	stats = ActorStats.new()

	stats.actor_name = enemy_name
	stats.max_hp = _calc_stat(hp_rank) * 5
	stats.starting_guard = int(level / 5) + guard_rank + 1
	stats.attack = _calc_stat(attack_rank)
	stats.psyche = _calc_stat(psyche_rank)
	stats.overload = _calc_stat(overload_rank)
	stats.speed = _calc_stat(speed_rank)
	stats.aim = int(level / 2) + aim_rank * 5
	stats.kinetic_defense = kinetic_defense_rank * 20 - 10
	stats.energy_defense = energy_defense_rank * 20 - 10

	print("\n=== STATS FOR: ", stats.actor_name, " ===")
	for prop in stats.get_property_list():
		# This filter ensures we only print variables defined in the script
		# (skips internal Godot stuff like 'reference', 'resource_path', etc.)
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			print(prop.name, ": ", stats.get(prop.name))
	print("========================\n")
	return stats

func _calc_stat(rank: int) -> int:
	var multiplier = _get_multiplier()
	var value = int((rank + 5) * multiplier)
	return int(value)

func _get_multiplier() -> int:
	return int(pow((level + 5), 2) * 0.048) * 2
