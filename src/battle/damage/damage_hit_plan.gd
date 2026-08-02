class_name DamageHitPlan
extends RefCounted

enum TargetMode { SINGLE, ALL, RANDOM }

var _candidates: Array[BattleCombatant]
var _planned_hit_count: int
var _distribution_count: int
var _target_mode: TargetMode

var candidates: Array[BattleCombatant]:
	get: return _candidates.duplicate()
var planned_hit_count: int:
	get: return _planned_hit_count
var distribution_count: int:
	get: return _distribution_count
var target_mode: TargetMode:
	get: return _target_mode


func _init(
	plan_candidates: Array[BattleCombatant],
	plan_hit_count: int,
	plan_split_damage: bool,
	plan_target_mode: TargetMode,
) -> void:
	_candidates.assign(plan_candidates)
	_planned_hit_count = maxi(0, plan_hit_count)
	_distribution_count = maxi(1, _planned_hit_count) if plan_split_damage else 1
	_target_mode = plan_target_mode


static func single_target(target: BattleCombatant, plan_hit_count: int, split_damage: bool) -> DamageHitPlan:
	var plan_candidates: Array[BattleCombatant] = []
	if target != null:
		plan_candidates.append(target)
	return DamageHitPlan.new(
		plan_candidates, plan_hit_count if target != null else 0,
		split_damage, TargetMode.SINGLE,
	)


static func all_targets(
	plan_candidates: Array[BattleCombatant],
	split_damage: bool,
) -> DamageHitPlan:
	return DamageHitPlan.new(
		plan_candidates, plan_candidates.size(), split_damage, TargetMode.ALL,
	)


static func random_targets(
	plan_candidates: Array[BattleCombatant],
	plan_hit_count: int,
	split_damage: bool,
) -> DamageHitPlan:
	return DamageHitPlan.new(
		plan_candidates, plan_hit_count, split_damage, TargetMode.RANDOM,
	)
