extends GutTest


func test_rejects_candidates_outside_requested_half_plane() -> void:
	var positions := {"current": Vector2.ZERO, "left": Vector2.LEFT, "right": Vector2.RIGHT}
	assert_eq(SkillTreeNavigation.find_directional_candidate("current", Vector2.RIGHT, positions), "right")


func test_smallest_angular_error_wins_before_distance() -> void:
	var positions := {"current": Vector2.ZERO, "near_angle": Vector2(1, 0.2), "aligned_far": Vector2(100, 0)}
	assert_eq(SkillTreeNavigation.find_directional_candidate("current", Vector2.RIGHT, positions), "aligned_far")


func test_distance_then_stable_id_break_equal_angle_ties() -> void:
	var positions := {"current": Vector2.ZERO, "far": Vector2(4, 4), "near": Vector2(2, 2)}
	assert_eq(SkillTreeNavigation.find_directional_candidate("current", Vector2(1, 1), positions), "near")
	positions = {"current": Vector2.ZERO, "zeta": Vector2(2, 2), "alpha": Vector2(2, 2)}
	assert_eq(SkillTreeNavigation.find_directional_candidate("current", Vector2(1, 1), positions), "alpha")


func test_invalid_inputs_and_no_candidate_return_empty_id() -> void:
	assert_eq(SkillTreeNavigation.find_directional_candidate("", Vector2.RIGHT, {}), "")
	assert_eq(SkillTreeNavigation.find_directional_candidate("current", Vector2.ZERO, {"current": Vector2.ZERO}), "")
	assert_eq(SkillTreeNavigation.find_directional_candidate("current", Vector2.RIGHT, {"current": Vector2.ZERO, "left": Vector2.LEFT}), "")


func test_role_header_exact_geometric_directions() -> void:
	var positions := {
		"gun.anchor": Vector2(0, 0),
		"gun.start1": Vector2(-300, 0),
		"gun.start2": Vector2(300, 0),
		"gun.root": Vector2(0, 90),
	}
	assert_eq(SkillTreeNavigation.find_directional_candidate("gun.anchor", Vector2.LEFT, positions), "gun.start1")
	assert_eq(SkillTreeNavigation.find_directional_candidate("gun.anchor", Vector2.RIGHT, positions), "gun.start2")
	assert_eq(SkillTreeNavigation.find_directional_candidate("gun.anchor", Vector2.DOWN, positions), "gun.root")
	assert_eq(SkillTreeNavigation.find_directional_candidate("gun.start1", Vector2.RIGHT, positions), "gun.anchor")
	assert_eq(SkillTreeNavigation.find_directional_candidate("gun.start2", Vector2.LEFT, positions), "gun.anchor")
