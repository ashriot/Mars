extends GutTest


func test_all_target_split_locks_recipient_count() -> void:
	var plan := DamageHitPlan.all_targets([Node.new(), Node.new(), Node.new()], true)
	assert_eq(plan.planned_hit_count, 3)
	assert_eq(plan.distribution_count, 3)
	_free_candidates(plan.candidates)


func test_random_split_uses_authored_hit_count_not_candidate_count() -> void:
	var plan := DamageHitPlan.random_targets([Node.new(), Node.new()], 3, true)
	assert_eq(plan.planned_hit_count, 3)
	assert_eq(plan.distribution_count, 3)
	_free_candidates(plan.candidates)


func test_unsplit_multihit_keeps_divisor_one() -> void:
	var target := Node.new()
	var plan := DamageHitPlan.single_target(target, 4, false)
	assert_eq(plan.planned_hit_count, 4)
	assert_eq(plan.distribution_count, 1)
	target.free()


func test_candidates_are_read_only_copies() -> void:
	var target := Node.new()
	var plan := DamageHitPlan.single_target(target, 1, false)
	var exposed_candidates := plan.candidates
	exposed_candidates.clear()
	assert_eq(plan.candidates, [target])
	target.free()


func _free_candidates(candidates: Array) -> void:
	for candidate in candidates:
		candidate.free()
