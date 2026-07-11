class_name ProgressionEffectApplier
extends RefCounted


func apply(effect: ProgressionEffect, stats: ActorStats, role: RoleData) -> bool:
	if effect == null or not effect.is_valid:
		return false
	match effect.type:
		ProgressionEffect.Type.STAT:
			var stat := _stat_from_name(effect.target)
			if stat < 0:
				return false
			stats.add_stat(stat as ActorStats.Stats, effect.amount)
			return true
		ProgressionEffect.Type.ACTION:
			var action := _load_action(effect.target)
			if action == null:
				return false
			if role.actions.size() < 4:
				role.actions.resize(4)
			if effect.amount >= role.actions.size():
				return false
			role.actions[effect.amount] = action
			return true
		ProgressionEffect.Type.PASSIVE:
			var passive := _load_action(effect.target)
			if passive == null:
				return false
			role.passive = passive
			return true
		ProgressionEffect.Type.SHIFT_ACTION:
			var shift_action := _load_action(effect.target)
			if shift_action == null:
				return false
			role.shift_action = shift_action
			return true
	return false


func _load_action(path: String) -> Action:
	if not ResourceLoader.exists(path):
		return null
	var resource := ResourceLoader.load(path)
	return resource as Action


func _stat_from_name(stat_name: String) -> int:
	var names := {
		"HP": ActorStats.Stats.HP,
		"GRD": ActorStats.Stats.GRD,
		"FOC": ActorStats.Stats.FOC,
		"ATK": ActorStats.Stats.ATK,
		"PSY": ActorStats.Stats.PSY,
		"OVR": ActorStats.Stats.OVR,
		"SPD": ActorStats.Stats.SPD,
		"AIM": ActorStats.Stats.AIM,
		"PRE": ActorStats.Stats.PRE,
		"KIN_DEF": ActorStats.Stats.KIN_DEF,
		"NRG_DEF": ActorStats.Stats.NRG_DEF,
	}
	return names.get(stat_name, -1)
