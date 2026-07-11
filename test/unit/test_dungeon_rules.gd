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


func _hero(injuries: int, focused := false, armored := false) -> HeroData:
	var hero := HeroData.new()
	hero.injuries = injuries
	hero.boon_focused = focused
	hero.boon_armored = armored
	return hero


func test_standard_medical_clears_injury_without_adding_boon() -> void:
	var hero := _hero(2)
	Rules.apply_medical_to_hero(hero, false, 0.9)
	assert_eq(hero.injuries, 0)
	assert_false(hero.boon_focused)
	assert_false(hero.boon_armored)


func test_standard_medical_gives_healthy_hero_one_rolled_boon() -> void:
	var focused := _hero(0)
	var armored := _hero(0)
	Rules.apply_medical_to_hero(focused, false, 0.9)
	Rules.apply_medical_to_hero(armored, false, 0.1)
	assert_true(focused.boon_focused)
	assert_false(focused.boon_armored)
	assert_false(armored.boon_focused)
	assert_true(armored.boon_armored)


func test_upgraded_medical_clears_injury_and_gives_one_rolled_boon() -> void:
	var hero := _hero(1)
	Rules.apply_medical_to_hero(hero, true, 0.1)
	assert_eq(hero.injuries, 0)
	assert_false(hero.boon_focused)
	assert_true(hero.boon_armored)


func test_upgraded_medical_gives_healthy_hero_both_boons() -> void:
	var hero := _hero(0)
	Rules.apply_medical_to_hero(hero, true, 0.1)
	assert_true(hero.boon_focused)
	assert_true(hero.boon_armored)


func test_medical_preserves_existing_boons_and_accepts_independent_rolls() -> void:
	var first := _hero(0, false, true)
	var second := _hero(0)
	Rules.apply_medical_to_hero(first, false, 0.9)
	Rules.apply_medical_to_hero(second, false, 0.1)
	assert_true(first.boon_focused)
	assert_true(first.boon_armored)
	assert_false(second.boon_focused)
	assert_true(second.boon_armored)
