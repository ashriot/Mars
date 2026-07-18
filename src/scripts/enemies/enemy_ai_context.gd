extends RefCounted
class_name EnemyAIContext

var heroes: Array[HeroCard] = []
var enemies: Array[EnemyCard] = []
var ticks_by_actor: Dictionary = {}
var encounter_seed := 0


func _init(living_heroes: Array[HeroCard], living_enemies: Array[EnemyCard],
	turn_ticks: Dictionary, seed_value: int) -> void:
	heroes.assign(living_heroes)
	enemies.assign(living_enemies)
	ticks_by_actor = turn_ticks.duplicate()
	encounter_seed = seed_value


func ticks_until(actor: ActorCard) -> int:
	return int(ticks_by_actor.get(actor, 1 << 30))
