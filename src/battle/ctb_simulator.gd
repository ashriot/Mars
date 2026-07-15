extends RefCounted
class_name CTBSimulator


static func project(
	actors: Array,
	target_ct: int,
	num_turns: int = 10,
	ct_adjustments: Dictionary = {}
) -> Array:
	var projection: Array = []
	var sim_data: Array[Dictionary] = []
	for actor: ActorCard in actors:
		if not is_instance_valid(actor) or actor.is_defeated:
			continue
		sim_data.append({
			"actor": actor,
			"ct": actor.current_ct + int(ct_adjustments.get(actor, 0)),
			"speed": maxi(actor.get_speed(), 1),
		})

	var elapsed_ticks := 0
	while projection.size() < num_turns and not sim_data.is_empty():
		var winner: Dictionary = {}
		var winner_ticks := 0
		for candidate: Dictionary in sim_data:
			var ticks := maxi(ceili(float(target_ct - candidate.ct) / candidate.speed), 0)
			if winner.is_empty() \
				or ticks < winner_ticks \
				or (ticks == winner_ticks and _comes_first(candidate, winner)):
				winner = candidate
				winner_ticks = ticks
		elapsed_ticks += winner_ticks
		projection.append({"actor": winner.actor, "ticks_needed": elapsed_ticks})
		for candidate: Dictionary in sim_data:
			candidate.ct += candidate.speed * winner_ticks
		winner.ct = 0
	return projection


static func _comes_first(candidate: Dictionary, incumbent: Dictionary) -> bool:
	if candidate.speed != incumbent.speed:
		return candidate.speed > incumbent.speed
	var candidate_is_hero := candidate.actor is HeroCard
	var incumbent_is_hero := incumbent.actor is HeroCard
	if candidate_is_hero != incumbent_is_hero:
		return candidate_is_hero
	return candidate.actor.battle_priority < incumbent.actor.battle_priority
