extends RefCounted
class_name EnemyAIContext

var heroes: Array[HeroCombatant] = []
var enemies: Array[EnemyCombatant] = []
var ticks_by_actor: Dictionary = {}
var encounter_seed := 0


func _init(living_heroes: Array[HeroCombatant], living_enemies: Array[EnemyCombatant],
	turn_ticks: Dictionary, seed_value: int) -> void:
	heroes.assign(living_heroes)
	enemies.assign(living_enemies)
	for value: BattleCombatant in turn_ticks:
		ticks_by_actor[value] = turn_ticks[value]
	encounter_seed = seed_value


func ticks_until(actor: BattleCombatant) -> int:
	return int(ticks_by_actor.get(actor, 1 << 30))
