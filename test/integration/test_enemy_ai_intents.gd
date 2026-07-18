extends GutTest


class QuietHero extends HeroCard:
	func _update_conditions_ui() -> void:
		return


class QuietEnemy extends EnemyCard:
	var intent_decision_count := 0

	func decide_intent(context: EnemyAIContext) -> void:
		intent_decision_count += 1
		super.decide_intent(context)

	func _update_intent_ui() -> void:
		return

	func show_action(_action_name: String) -> void:
		return

	func hide_action() -> void:
		return


class QuietBattleManager extends BattleManager:
	var executed_action: Action
	var executed_targets: Array = []

	func wait(_duration: float = 0.01) -> void:
		return

	func execute_action(_actor: ActorCard, action: Action, targets: Array,
		_display_name: bool = true, _ends_turn: bool = false) -> void:
		executed_action = action
		executed_targets = targets.duplicate()


func test_refresh_changes_reactive_intent_without_ticking_cooldowns() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 0
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"focus_attack")
	assert_eq(fixture.enemy.ai_state.completed_turns, 0)
	assert_eq(fixture.enemy.ai_state.remaining(&"focus_attack"), 0)
	_free_fixture(fixture)


func test_completed_turn_sets_only_used_cooldown_and_plans_next_intent() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	var used_id: StringName = fixture.enemy.intended_decision.ability.ability_id
	fixture.enemy.complete_ai_turn(used_id)
	assert_eq(fixture.enemy.ai_state.completed_turns, 1)
	assert_gt(fixture.enemy.ai_state.remaining(used_id), 0)
	fixture.manager._update_all_enemy_intents()
	assert_ne(fixture.enemy.intended_decision.ability.ability_id, used_id)
	_free_fixture(fixture)


func test_breached_enemy_intends_recovery_and_ticks_a_recovery_turn() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.enemy.is_breached = true
	fixture.manager._update_all_enemy_intents()
	assert_true(fixture.enemy.intended_decision.is_recovery)
	fixture.enemy.complete_ai_turn()
	assert_eq(fixture.enemy.ai_state.completed_turns, 1)
	_free_fixture(fixture)


func test_execution_reselects_once_when_cached_target_is_invalid() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	var stale_action: Action = fixture.enemy.intended_action
	fixture.echo.is_defeated = true
	await fixture.manager.execute_enemy_turn(fixture.enemy)
	assert_eq(fixture.enemy.intent_decision_count, 2)
	assert_ne(fixture.manager.executed_action, stale_action)
	assert_eq(fixture.manager.executed_targets, [fixture.sands])
	assert_eq(fixture.enemy.ai_state.completed_turns, 1)
	assert_eq(fixture.enemy.ai_state.remaining(&"focus_attack"), 0)
	_free_fixture(fixture)


func test_execution_fails_safely_when_reselection_is_still_invalid() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	fixture.sands.is_defeated = true
	fixture.echo.is_defeated = true
	await fixture.manager.execute_enemy_turn(fixture.enemy)
	assert_eq(fixture.enemy.intent_decision_count, 2)
	assert_null(fixture.manager.executed_action)
	assert_eq(fixture.enemy.ai_state.completed_turns, 1)
	assert_eq(fixture.enemy.ai_state.remaining(&"focus_attack"), 0)
	assert_push_error("could not produce a valid intent")
	assert_push_error("no executable intent")
	_free_fixture(fixture)


func _fixture() -> Dictionary:
	var manager := QuietBattleManager.new()
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	manager.encounter_seed = 77

	var sands := QuietHero.new()
	var echo := QuietHero.new()
	var enemy := QuietEnemy.new()
	_initialize_actor(sands, "Sands", 1)
	_initialize_actor(echo, "Echo", 2)
	_initialize_actor(enemy, "Drone", 3)
	manager.hero_area.add_child(sands)
	manager.hero_area.add_child(echo)
	manager.enemy_area.add_child(enemy)
	manager.actor_list = [sands, echo, enemy]

	var basic := _ability(
		&"basic", 0, 10, EnemyDecisionCondition.Type.ALWAYS,
		EnemyTargetSelector.Type.SEEDED_HERO, 0.0,
	)
	var focus_attack := _ability(
		&"focus_attack", 3, 100, EnemyDecisionCondition.Type.ANY_HERO_FOCUS_AT_LEAST,
		EnemyTargetSelector.Type.HIGHEST_FOCUS_HERO, 5.0,
	)
	var enemy_data := EnemyData.new()
	enemy_data.abilities = [basic, focus_attack]
	enemy.enemy_data = enemy_data
	enemy.recover_action = _action("Recover", Action.TargetType.SELF)
	return {
		"manager": manager,
		"sands": sands,
		"echo": echo,
		"enemy": enemy,
	}


func _initialize_actor(actor: ActorCard, actor_name: String, priority: int) -> void:
	actor.actor_name = actor_name
	actor.current_stats = ActorStats.new()
	actor.current_stats.actor_name = actor_name
	actor.current_stats.max_hp = 100
	actor.current_stats.speed = 10
	actor.current_hp = 100
	actor.current_guard = 2
	actor.current_ct = 0
	actor.battle_priority = priority
	actor.is_breached = false
	actor.is_defeated = false


func _ability(id: StringName, cooldown: int, priority: int,
	condition_type: EnemyDecisionCondition.Type, selector_type: EnemyTargetSelector.Type,
	threshold: float) -> EnemyAbility:
	var condition := EnemyDecisionCondition.new()
	condition.type = condition_type
	condition.threshold = threshold
	var selector := EnemyTargetSelector.new()
	selector.type = selector_type
	var rule := EnemyDecisionRule.new()
	rule.priority = priority
	rule.conditions = [condition]
	rule.selector = selector
	rule.reason = "integration fixture"
	var ability := EnemyAbility.new()
	ability.ability_id = id
	ability.action = _action(String(id), Action.TargetType.ONE_ENEMY)
	ability.cooldown_turns = cooldown
	ability.rules = [rule]
	return ability


func _action(action_name: String, target_type: Action.TargetType) -> Action:
	var action := Action.new()
	action.action_name = action_name
	action.target_type = target_type
	return action


func _free_fixture(fixture: Dictionary) -> void:
	(fixture.manager as BattleManager).free()
