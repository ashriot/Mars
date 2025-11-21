extends Resource
class_name HeroData

@export var hero_id: String = "asher"
@export var hero_name: String = "asher"
@export var portrait: Texture

# Equipment slots
@export var weapon: Equipment
@export var armor: Equipment
@export var accessory_1: Equipment
@export var accessory_2: Equipment

@export var unlocked_roles: Array[RoleData]

# Role progression (one entry per role)
@export var role_progressions: Array[RoleProgression] = []

# Currently active role index
@export var active_role_index: int = 0

var stats: ActorStats

func get_role_progression(role_id: String) -> RoleProgression:
	for prog in role_progressions:
		if prog.role_id == role_id:
			return prog
	return null

func calculate_stats():
	stats = ActorStats.new()
	stats.actor_name = hero_name
	# Apply equipment (now calculated based on level)
	if weapon:
		var weapon_stats = weapon.calculate_stats()
		_add_stats(stats, weapon_stats)
		_apply_special_effect(stats, weapon)

	if armor:
		var armor_stats = armor.calculate_stats()
		_add_stats(stats, armor_stats)
		_apply_special_effect(stats, armor)

	if accessory_1:
		var acc1_stats = accessory_1.calculate_stats()
		_add_stats(stats, acc1_stats)
		_apply_special_effect(stats, accessory_1)

	if accessory_2:
		var acc2_stats = accessory_2.calculate_stats()
		_add_stats(stats, acc2_stats)
		_apply_special_effect(stats, accessory_2)

	# Apply ALL role progression bonuses
	for progression in role_progressions:
		for stat_type in progression.stat_bonuses:
			stats.add_stat(stat_type, progression.stat_bonuses[stat_type])

	return stats

# HeroData.gd - Add these helper functions

func _add_stats(base: ActorStats, additional: ActorStats):
	base.max_hp += additional.max_hp
	base.starting_guard += additional.starting_guard
	base.attack += additional.attack
	base.psyche += additional.psyche
	base.overload += additional.overload
	base.speed += additional.speed
	base.aim = clampi(base.aim + additional.aim, 0, 75)
	base.kinetic_defense = clampi(base.kinetic_defense + additional.kinetic_defense, 0, 90)
	base.energy_defense = clampi(base.energy_defense + additional.energy_defense, 0, 90)

func _apply_special_effect(actor_stats: ActorStats, equipment: Equipment):
	match equipment.special_effect:
		"advantage_1", "advantage_2", "advantage_3":
			# Starting Focus bonus handled in combat initialization
			pass
		"fortified":
			# Critical hits don't shred extra Guard - handled in combat
			pass
		"glass_cannon":
			# Apply HP penalty (-20% HP)
			var penalty = int(actor_stats.max_hp * abs(equipment.special_effect_value) / 100.0)
			actor_stats.max_hp = max(1, actor_stats.max_hp - penalty)
		"paladin":
			# Damage reduction handled in combat
			pass
		_:
			# Unknown special effect, ignore
			pass
