extends RefCounted
class_name EnemyAIContext

var heroes: Array[HeroCombatant] = []
var enemies: Array[EnemyCombatant] = []
var ticks_by_actor: Dictionary = {}
var encounter_seed := 0


func _init(living_heroes: Array, living_enemies: Array,
	turn_ticks: Dictionary, seed_value: int) -> void:
	for value: Node in living_heroes:
		heroes.append(BattleCombatant.resolve_model(value) as HeroCombatant)
	for value: Node in living_enemies:
		enemies.append(BattleCombatant.resolve_model(value) as EnemyCombatant)
	for value: Node in turn_ticks:
		ticks_by_actor[BattleCombatant.resolve_model(value)] = turn_ticks[value]
	encounter_seed = seed_value


func ticks_until(actor: BattleCombatant) -> int:
	return int(ticks_by_actor.get(actor, 1 << 30))
