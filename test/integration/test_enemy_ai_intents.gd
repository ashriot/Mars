extends GutTest


class QuietHero extends HeroCard:
	func _update_conditions_ui() -> void:
		return


class QuietEnemy extends EnemyCard:
	var intent_decision_count := 0
	var intent_flash_count := 0

	func decide_intent(context: EnemyAIContext) -> void:
		intent_decision_count += 1
		super.decide_intent(context)

	func _update_intent_ui() -> void:
		return

	func flash_intent(_duration: float = 0.3) -> void:
		intent_flash_count += 1

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


func test_identical_planning_and_presentation_refresh_do_not_flash_again() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intent_flash_count, 1)
	fixture.manager._update_all_enemy_intents()
	fixture.enemy.refresh_intent_presentation()
	assert_eq(fixture.enemy.intent_flash_count, 1)
	_free_fixture(fixture)


func test_focus_signal_preserves_locked_intent() -> void:
	var fixture := _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	fixture.echo.current_focus = 6
	fixture.echo.focus_updated.emit()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	assert_eq(fixture.enemy.intent_decision_count, 1)
	_free_fixture(fixture)


func test_hp_signal_preserves_locked_intent() -> void:
	var fixture := _fixture()
	fixture.enemy.enemy_data.abilities.append(_ability(
		&"repair", 2, 200, EnemyDecisionCondition.Type.SELF_HP_AT_MOST,
		EnemyTargetSelector.Type.SELF, 0.5,
	))
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	fixture.enemy.current_hp = 40
	fixture.enemy.hp_changed.emit(40, 100)
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	assert_eq(fixture.enemy.intent_decision_count, 1)
	_free_fixture(fixture)


func test_guard_signal_preserves_locked_intent() -> void:
	var fixture := _fixture()
	fixture.enemy.enemy_data.abilities.append(_ability(
		&"guard_attack", 2, 200, EnemyDecisionCondition.Type.ANY_HERO_GUARD_AT_LEAST,
		EnemyTargetSelector.Type.HIGHEST_GUARD_HERO, 5.0,
	))
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	fixture.echo.current_guard = 8
	fixture.echo.armor_changed.emit(8)
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	assert_eq(fixture.enemy.intent_decision_count, 1)
	_free_fixture(fixture)


func test_turn_order_refresh_preserves_locked_intent() -> void:
	var fixture := _fixture()
	fixture.enemy.enemy_data.abilities.append(_ability(
		&"imminent", 2, 200, EnemyDecisionCondition.Type.HERO_TURN_WITHIN,
		EnemyTargetSelector.Type.HERO_CLOSEST_TO_ACTING, 5.0,
	))
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	fixture.echo.current_ct = 3950
	fixture.manager.update_turn_order()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	assert_eq(fixture.enemy.intent_decision_count, 1)
	_free_fixture(fixture)


func test_decoy_retargets_locked_action_without_replanning() -> void:
	var fixture := _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	var locked_action: Action = fixture.enemy.intended_action
	var original_target := fixture.enemy.intended_targets[0] as HeroCard
	var decoy := Condition.new()
	decoy.condition_name = "Decoy"
	decoy.is_untargetable = true
	await original_target.add_condition(decoy)
	assert_eq(fixture.enemy.intended_action, locked_action)
	assert_ne(fixture.enemy.intended_targets, [original_target])
	assert_eq(fixture.enemy.intent_decision_count, 1)
	assert_eq(fixture.enemy.intent_flash_count, 2)
	_free_fixture(fixture)


func test_taunt_redirects_locked_action_without_replanning() -> void:
	var fixture := _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	var locked_action: Action = fixture.enemy.intended_action
	var original_target := fixture.enemy.intended_targets[0] as HeroCard
	var taunter: HeroCard = fixture.sands \
		if original_target == fixture.echo else fixture.echo
	var draw_fire := Condition.new()
	draw_fire.condition_name = "Draw Fire"
	draw_fire.is_taunting = true
	await taunter.add_condition(draw_fire)
	assert_eq(fixture.enemy.intended_action, locked_action)
	assert_eq(fixture.enemy.intended_targets, [taunter])
	assert_eq(fixture.enemy.intent_decision_count, 1)
	assert_eq(fixture.enemy.intent_flash_count, 2)
	_free_fixture(fixture)


func test_ordinary_condition_does_not_change_locked_targets() -> void:
	var fixture := _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	var locked_action: Action = fixture.enemy.intended_action
	var locked_targets: Array[ActorCard] = []
	locked_targets.assign(fixture.enemy.intended_targets)
	var buff := Condition.new()
	buff.condition_name = "Ordinary Buff"
	await fixture.echo.add_condition(buff)
	assert_eq(fixture.enemy.intended_action, locked_action)
	assert_eq(fixture.enemy.intended_targets, locked_targets)
	assert_eq(fixture.enemy.intent_decision_count, 1)
	assert_eq(fixture.enemy.intent_flash_count, 1)
	_free_fixture(fixture)


func test_final_startup_timing_refreshes_intents_after_head_starts() -> void:
	var fixture := _fixture()
	fixture.enemy.enemy_data.abilities.append(_ability(
		&"imminent", 2, 200, EnemyDecisionCondition.Type.HERO_TURN_WITHIN,
		EnemyTargetSelector.Type.HERO_CLOSEST_TO_ACTING, 35.0,
	))
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	fixture.manager._finalize_initial_ai_timing([0.0, 1.0, 0.0])
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"imminent")
	assert_eq(fixture.enemy.intent_decision_count, 2)
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
	fixture.manager._update_all_enemy_intents()
	fixture.enemy.is_breached = true
	await fixture.manager._on_actor_breached(fixture.enemy)
	assert_true(fixture.enemy.intended_decision.is_recovery)
	assert_eq(fixture.enemy.intent_decision_count, 2)
	fixture.enemy.complete_ai_turn()
	assert_eq(fixture.enemy.ai_state.completed_turns, 1)
	_free_fixture(fixture)


func test_execution_retargets_cached_action_when_target_is_invalid() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	var stale_action: Action = fixture.enemy.intended_action
	fixture.echo.is_defeated = true
	await fixture.manager.execute_enemy_turn(fixture.enemy)
	assert_eq(fixture.enemy.intent_decision_count, 1)
	assert_eq(fixture.manager.executed_action, stale_action)
	assert_eq(fixture.manager.executed_targets, [fixture.sands])
	assert_eq(fixture.enemy.ai_state.completed_turns, 1)
	assert_eq(fixture.enemy.ai_state.remaining(&"focus_attack"), 3)
	_free_fixture(fixture)


func test_execution_keeps_cached_action_when_trigger_no_longer_matches() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	var stale_action: Action = fixture.enemy.intended_action
	fixture.echo.current_focus = 0
	await fixture.manager.execute_enemy_turn(fixture.enemy)
	assert_eq(fixture.enemy.intent_decision_count, 1)
	assert_eq(fixture.manager.executed_action, stale_action)
	assert_eq(fixture.enemy.ai_state.remaining(&"focus_attack"), 3)
	_free_fixture(fixture)


func test_execution_skips_locked_ability_that_became_unavailable() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	fixture.enemy.complete_ai_turn(&"focus_attack")
	await fixture.manager.execute_enemy_turn(fixture.enemy)
	assert_eq(fixture.enemy.intent_decision_count, 1)
	assert_null(fixture.manager.executed_action)
	assert_null(fixture.enemy.intended_action)
	assert_eq(fixture.enemy.ai_state.remaining(&"focus_attack"), 2)
	assert_push_error("no executable locked intent")
	_free_fixture(fixture)


func test_execution_fails_safely_when_locked_action_has_no_legal_target() -> void:
	var fixture := _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.echo.current_focus = 6
	fixture.manager._update_all_enemy_intents()
	fixture.sands.is_defeated = true
	fixture.echo.is_defeated = true
	await fixture.manager.execute_enemy_turn(fixture.enemy)
	assert_eq(fixture.enemy.intent_decision_count, 1)
	assert_null(fixture.manager.executed_action)
	assert_eq(fixture.enemy.ai_state.completed_turns, 1)
	assert_eq(fixture.enemy.ai_state.remaining(&"focus_attack"), 0)
	assert_push_error("no executable locked intent")
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


func _connect_actor_refresh_signals(fixture: Dictionary) -> void:
	var manager := fixture.manager as BattleManager
	for actor: ActorCard in manager.actor_list:
		manager._connect_actor_intent_refresh_signals(actor)
		actor.actor_conditions_changed.connect(manager._on_actor_conditions_changed)


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
