extends RefCounted
class_name EnemyDecision

var ability: EnemyAbility
var action: Action
var rule: EnemyDecisionRule
var targets: Array[BattleCombatant] = []
var reason: String = ""
var is_recovery := false


func is_valid() -> bool:
	return action != null and not targets.is_empty()
