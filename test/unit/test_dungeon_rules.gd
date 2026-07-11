extends GutTest

const Rules = preload("res://src/map/dungeon_rules.gd")


func test_calculate_count_applies_multiplier_once() -> void:
	assert_eq(Rules.calculate_count(300, 2.0, 1.5), 9)


func test_apply_minimum_enforces_terminal_floor() -> void:
	assert_eq(Rules.apply_minimum(0, Rules.MIN_TERMINALS), 2)
	assert_eq(Rules.apply_minimum(6, Rules.MIN_TERMINALS), 6)


func test_actionable_total_excludes_endpoints_and_counts_optional_boss() -> void:
	var counts = {
		"terminal": 2,
		"combat": 3,
		"elite": 1,
		"reward_common": 1,
		"reward_uncommon": 1,
		"reward_rare": 0,
		"reward_epic": 0,
		"event": 2,
	}

	assert_eq(Rules.actionable_total(counts, false), 10)
	assert_eq(Rules.actionable_total(counts, true), 11)


func test_normalized_tier_clamps_to_minimum() -> void:
	assert_eq(Rules.normalized_tier(0), 1)


func test_loot_scalar_scales_from_normalized_tier() -> void:
	assert_eq(Rules.loot_scalar(1), 1.0)
	assert_eq(Rules.loot_scalar(3), 1.5)
