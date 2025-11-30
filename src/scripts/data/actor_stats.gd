extends Resource
class_name ActorStats

enum Stats {
	HP, GRD, FOC, ATK, PSY, OVR, SPD, AIM, KIN_DEF, NRG_DEF
}

var actor_name: String
var max_hp: int = 0
var starting_guard: int = 0
var starting_focus: int = 0
var attack: int = 0
var psyche: int = 0
var overload: int = 0
var speed: int = 0
var aim: int = 0
var aim_dmg: int = 0
var kinetic_defense: int = 0
var energy_defense: int = 0

func get_stat(stat: Stats) -> int:
	match stat:
		Stats.HP: return max_hp
		Stats.GRD: return starting_guard
		Stats.FOC: return starting_focus
		Stats.ATK: return attack
		Stats.PSY: return psyche
		Stats.OVR: return overload
		Stats.SPD: return speed
		Stats.AIM: return aim
		Stats.KIN_DEF: return kinetic_defense
		Stats.NRG_DEF: return energy_defense
	return 0

func add_stat(stat: Stats, value: int):
	match stat:
		Stats.HP: max_hp += value
		Stats.GRD: starting_guard += value
		Stats.FOC: starting_focus += value
		Stats.ATK: attack += value
		Stats.PSY: psyche += value
		Stats.OVR: overload += value
		Stats.SPD: speed += value
		Stats.AIM: aim = clampi(aim + value, 0, 75)
		Stats.KIN_DEF: kinetic_defense = clampi(kinetic_defense + value, 0, 90)
		Stats.NRG_DEF: energy_defense = clampi(energy_defense + value, 0, 90)

func _to_string() -> String:
	return "%s | HP:%d GRD:%d FOC:%d\nATK:%d PSY:%d OVR:%d SPD:%d\nAIM:%d%% DMG: %d KIN:%d%% NRG:%d%%" % [
		actor_name,
		max_hp,
		starting_guard,
		starting_focus,
		attack,
		psyche,
		overload,
		speed,
		aim,
		aim_dmg,
		kinetic_defense,
		energy_defense
	]
