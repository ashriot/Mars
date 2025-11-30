extends Resource
class_name ActorStats

enum Stats {
	HP, GRD, ATK, PSY, OVR, SPD, PRC, KIN_DEF, NRG_DEF
}

var actor_name: String
var max_hp: int = 15
var starting_guard: int = 0
var starting_focus: int = 4
var attack: int = 5
var psyche: int = 5
var overload: int = 15
var speed: int = 5
var aim: int = 0
var aim_bonus: int = 50
var kinetic_defense: int = 0
var energy_defense: int = 0

func get_stat(stat: Stats) -> int:
	match stat:
		Stats.HP: return max_hp
		Stats.GRD: return starting_guard
		Stats.ATK: return attack
		Stats.PSY: return psyche
		Stats.OVR: return overload
		Stats.SPD: return speed
		Stats.PRC: return aim
		Stats.KIN_DEF: return kinetic_defense
		Stats.NRG_DEF: return energy_defense
	return 0

func add_stat(stat: Stats, value: int):
	match stat:
		Stats.HP: max_hp += value
		Stats.GRD: starting_guard += value
		Stats.ATK: attack += value
		Stats.PSY: psyche += value
		Stats.OVR: overload += value
		Stats.SPD: speed += value
		Stats.PRC: aim = clampi(aim + value, 0, 75)
		Stats.KIN_DEF: kinetic_defense = clampi(kinetic_defense + value, 0, 90)
		Stats.NRG_DEF: energy_defense = clampi(energy_defense + value, 0, 90)

func _to_string() -> String:
	return "%s | HP:%d GRD:%d | ATK:%d PSY:%d OVR:%d SPD:%d | AIM:%d%% KIN:%d%% NRG:%d%%" % [
		actor_name,
		max_hp,
		starting_guard,
		attack,
		psyche,
		overload,
		speed,
		aim,
		kinetic_defense,
		energy_defense
	]
