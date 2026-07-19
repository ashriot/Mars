extends GutTest


func _free_ability(id: StringName = &"basic") -> EnemyAbility:
	var selector := EnemyTargetSelector.new()
	selector.type = EnemyTargetSelector.Type.SEEDED_HERO
	var rule := EnemyDecisionRule.new()
	rule.priority = 0
	rule.selector = selector
	var ability := EnemyAbility.new()
	ability.ability_id = id
	ability.action = Action.new()
	ability.cooldown_turns = 0
	ability.initial_cooldown = 0
	ability.rules = [rule]
	return ability


func _has_error(errors: PackedStringArray, needle: String) -> bool:
	for value in errors:
		if needle in value:
			return true
	return false


func test_valid_kit_requires_one_unconditional_free_action() -> void:
	var enemy := EnemyData.new()
	enemy.enemy_id = "valid"
	enemy.abilities = [_free_ability()]
	assert_true(EnemyKitValidator.validate(enemy).is_empty())


func test_kit_rejects_duplicate_ids_and_missing_fallback() -> void:
	var first := _free_ability(&"same")
	first.cooldown_turns = 1
	first.initial_cooldown = 1
	var second := _free_ability(&"same")
	second.cooldown_turns = 2
	second.initial_cooldown = 1
	var enemy := EnemyData.new()
	enemy.enemy_id = "invalid"
	enemy.abilities = [first, second]
	var errors := EnemyKitValidator.validate(enemy, "res://invalid.tres")
	assert_true(_has_error(errors, "Duplicate ability ID 'same'"))
	assert_true(_has_error(errors, "unconditional free action"))


func test_ability_rejects_invalid_cooldowns_null_action_and_missing_rules() -> void:
	var ability := EnemyAbility.new()
	ability.ability_id = &"broken"
	ability.cooldown_turns = 2
	ability.initial_cooldown = 3
	var errors := ability.validate("enemy")
	assert_true(_has_error(errors, "action"))
	assert_true(_has_error(errors, "initial_cooldown"))
	assert_true(_has_error(errors, "rules"))


func test_one_time_free_action_is_not_a_valid_fallback() -> void:
	var ability := _free_ability()
	ability.one_time_use = true
	var enemy := EnemyData.new()
	enemy.abilities = [ability]
	var errors := EnemyKitValidator.validate(enemy)
	assert_true(_has_error(errors, "unconditional free action"))


func test_lone_enemy_ally_only_rule_is_not_a_valid_fallback() -> void:
	var ability := _free_ability()
	ability.action.target_type = Action.TargetType.ONE_ALLY
	ability.rules[0].selector.type = EnemyTargetSelector.Type.LEAST_GUARD_ALLY
	ability.rules[0].selector.exclude_self = true
	var enemy := EnemyData.new()
	enemy.abilities = [ability]
	var errors := EnemyKitValidator.validate(enemy)
	assert_true(_has_error(errors, "guaranteed legal target"))


func test_random_hit_action_requires_the_complete_valid_candidate_pool() -> void:
	var ability := _free_ability()
	ability.action.target_type = Action.TargetType.RANDOM_ENEMY
	var errors := ability.validate("enemy")
	assert_true(_has_error(errors, "VALID_HERO_CANDIDATES"))
	ability.rules[0].selector.type = EnemyTargetSelector.Type.VALID_HERO_CANDIDATES
	assert_true(ability.validate("enemy").is_empty())
