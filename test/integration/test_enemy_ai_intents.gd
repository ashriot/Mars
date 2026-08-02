extends GutTest

const HeroCardScene := preload("res://src/battle/hero_card.tscn")
const EnemyCardScene := preload("res://src/battle/enemy_card.tscn")


class QuietHero extends HeroCard:
	func _update_conditions_ui() -> void:
		return


class QuietEnemy extends EnemyCard:
	var intent_decision_count := 0
	var intent_flash_count := 0
	var intent_presentation_refresh_count := 0

	func decide_intent(context: EnemyAIContext) -> void:
		intent_decision_count += 1
		super.decide_intent(context)

	func _update_intent_ui() -> void:
		return

	func refresh_intent_presentation() -> void:
		intent_presentation_refresh_count += 1
		super.refresh_intent_presentation()

	func flash_intent(_duration: float = 0.3) -> void:
		intent_flash_count += 1

	func show_action(_action_name: String) -> void:
		return

	func hide_action() -> void:
		return


class QuietBattleManager extends BattleManager:
	var executed_action: Action
	var executed_targets: Array = []

	func _ready() -> void:
		pass

	func wait(_duration: float = 0.01) -> void:
		return

	func execute_action(_actor: ActorCard, action: Action, targets: Array,
		_display_name: bool = true, _ends_turn: bool = false) -> void:
		executed_action = action
		executed_targets = targets.duplicate()


class ProductionEffectBattleManager extends BattleManager:
	func _ready() -> void:
		pass

	func wait(_duration: float = 0.01) -> void:
		return


func test_refresh_changes_reactive_intent_without_ticking_cooldowns() -> void:
	var fixture := await _fixture()
	fixture.enemy.initialize_ai(77)
	(fixture.echo.combatant as HeroCombatant).current_focus = 0
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	(fixture.echo.combatant as HeroCombatant).current_focus = 6
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"focus_attack")
	assert_eq(fixture.enemy.ai_state.completed_turns, 0)
	assert_eq(fixture.enemy.ai_state.remaining(&"focus_attack"), 0)
	_free_fixture(fixture)


func test_identical_planning_and_presentation_refresh_do_not_flash_again() -> void:
	var fixture := await _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intent_flash_count, 1)
	fixture.manager._update_all_enemy_intents()
	fixture.enemy.refresh_intent_presentation()
	assert_eq(fixture.enemy.intent_flash_count, 1)
	_free_fixture(fixture)


func test_clearing_spent_intent_refreshes_without_flashing_again() -> void:
	var fixture := await _fixture()
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intent_flash_count, 1)

	fixture.enemy.clear_intent()

	assert_null(fixture.enemy.intended_action)
	assert_eq(fixture.enemy.intent_flash_count, 1)
	_free_fixture(fixture)


func test_focus_signal_preserves_locked_intent() -> void:
	var fixture := await _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	(fixture.echo.combatant as HeroCombatant).current_focus = 6
	fixture.echo.focus_updated.emit()
	assert_eq(fixture.enemy.intended_decision.ability.ability_id, &"basic")
	assert_eq(fixture.enemy.intent_decision_count, 1)
	_free_fixture(fixture)


func test_hp_signal_preserves_locked_intent() -> void:
	var fixture := await _fixture()
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
	var fixture := await _fixture()
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
	var fixture := await _fixture()
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
	var fixture := await _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	var locked_action: Action = fixture.enemy.intended_action
	var original_target := fixture.enemy.intended_targets[0] as HeroCombatant
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
	var fixture := await _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	var locked_action: Action = fixture.enemy.intended_action
	var original_target := fixture.enemy.intended_targets[0] as HeroCombatant
	var taunter := fixture.sands.combatant as HeroCombatant \
		if original_target == fixture.echo.combatant \
		else fixture.echo.combatant as HeroCombatant
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
	var fixture := await _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	var locked_action: Action = fixture.enemy.intended_action
	var locked_targets: Array[BattleCombatant] = []
	locked_targets.assign(fixture.enemy.intended_targets)
	var buff := Condition.new()
	buff.condition_name = "Ordinary Buff"
	await fixture.echo.add_condition(buff)
	assert_eq(fixture.enemy.intended_action, locked_action)
	assert_eq(fixture.enemy.intended_targets, locked_targets)
	assert_eq(fixture.enemy.intent_decision_count, 1)
	assert_eq(fixture.enemy.intent_flash_count, 1)
	_free_fixture(fixture)


func test_debilitate_refreshes_locked_intent_presentation_without_replanning() -> void:
	var fixture := await _fixture()
	_connect_actor_refresh_signals(fixture)
	fixture.enemy.initialize_ai(77)
	fixture.manager._update_all_enemy_intents()
	var locked_action: Action = fixture.enemy.intended_action
	var debilitate_action := load(
		"res://data/heroes/asher/actions/debilitate.tres"
	) as Action
	var apply_effect := debilitate_action.effects[0] as Effect_ApplyCondition
	fixture.enemy.active_conditions.append(apply_effect.condition.duplicate(true))
	fixture.enemy.actor_conditions_changed.emit()
	assert_eq(fixture.enemy.intended_action, locked_action)
	assert_eq(fixture.enemy.intent_decision_count, 1)
	assert_eq(fixture.enemy.intent_presentation_refresh_count, 1)
	assert_eq(fixture.enemy.intent_flash_count, 1)
	_free_fixture(fixture)


func test_final_startup_timing_refreshes_intents_after_head_starts() -> void:
	var fixture := await _fixture()
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
	var fixture := await _fixture()
	fixture.enemy.initialize_ai(77)
	(fixture.echo.combatant as HeroCombatant).current_focus = 6
	fixture.manager._update_all_enemy_intents()
	var used_id: StringName = fixture.enemy.intended_decision.ability.ability_id
	fixture.enemy.complete_ai_turn(used_id)
	assert_eq(fixture.enemy.ai_state.completed_turns, 1)
	assert_gt(fixture.enemy.ai_state.remaining(used_id), 0)
	fixture.manager._update_all_enemy_intents()
	assert_ne(fixture.enemy.intended_decision.ability.ability_id, used_id)
	_free_fixture(fixture)


func test_breached_enemy_intends_recovery_and_ticks_a_recovery_turn() -> void:
	var fixture := await _fixture()
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
	var fixture := await _fixture()
	fixture.enemy.initialize_ai(77)
	(fixture.echo.combatant as HeroCombatant).current_focus = 6
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
	var fixture := await _fixture()
	fixture.enemy.initialize_ai(77)
	(fixture.echo.combatant as HeroCombatant).current_focus = 6
	fixture.manager._update_all_enemy_intents()
	var stale_action: Action = fixture.enemy.intended_action
	(fixture.echo.combatant as HeroCombatant).current_focus = 0
	await fixture.manager.execute_enemy_turn(fixture.enemy)
	assert_eq(fixture.enemy.intent_decision_count, 1)
	assert_eq(fixture.manager.executed_action, stale_action)
	assert_eq(fixture.enemy.ai_state.remaining(&"focus_attack"), 3)
	_free_fixture(fixture)


func test_execution_skips_locked_ability_that_became_unavailable() -> void:
	var fixture := await _fixture()
	fixture.enemy.initialize_ai(77)
	(fixture.echo.combatant as HeroCombatant).current_focus = 6
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
	var fixture := await _fixture()
	fixture.enemy.initialize_ai(77)
	(fixture.echo.combatant as HeroCombatant).current_focus = 6
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


func test_real_enemy_damage_turn_reduces_bound_hero_hp() -> void:
	var fixture := await _production_execution_fixture()
	var manager := fixture.manager as BattleManager
	var enemy := fixture.enemy as EnemyCard
	var hero := fixture.hero as HeroCard
	var starting_hp := hero.current_hp

	enemy.initialize_ai(77)
	enemy.decide_intent(manager._enemy_ai_context())
	manager.current_actor = enemy
	await manager.execute_enemy_turn(enemy)

	assert_lt(hero.current_hp, starting_hp)
	_free_fixture(fixture)


func test_real_enemy_recovery_intent_is_executable() -> void:
	var fixture := await _production_execution_fixture()
	var manager := fixture.manager as BattleManager
	var enemy := fixture.enemy as EnemyCard
	var model := enemy.combatant as EnemyCombatant
	model.is_breached = true
	model.current_guard = 0

	enemy.initialize_ai(77)
	enemy.decide_intent(manager._enemy_ai_context())
	manager.current_actor = enemy
	await manager.execute_enemy_turn(enemy)

	assert_false(model.is_breached)
	assert_gt(model.current_guard, 0)
	_free_fixture(fixture)


func _fixture() -> Dictionary:
	var manager := QuietBattleManager.new()
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	add_child_autofree(manager)
	manager.encounter_seed = 77

	var sands := _scene_backed_card(HeroCardScene, QuietHero.new()) as QuietHero
	var echo := _scene_backed_card(HeroCardScene, QuietHero.new()) as QuietHero
	var enemy := _scene_backed_card(EnemyCardScene, QuietEnemy.new()) as QuietEnemy
	manager.hero_area.add_child(sands)
	manager.hero_area.add_child(echo)
	manager.enemy_area.add_child(enemy)
	await get_tree().process_frame
	var _sands_model := _bind_actor(
		sands, BattleCombatant.Faction.HERO, "Sands", 1, manager,
	) as HeroCombatant
	var _echo_model := _bind_actor(
		echo, BattleCombatant.Faction.HERO, "Echo", 2, manager,
	) as HeroCombatant
	var enemy_model := _bind_actor(
		enemy, BattleCombatant.Faction.ENEMY, "Drone", 3, manager,
	) as EnemyCombatant
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
	enemy_data.recover_action = _action("Recover", Action.TargetType.SELF)
	enemy_model.enemy_data = enemy_data
	enemy_model.recover_action = enemy_data.recover_action
	enemy_model.presentation_event.connect(enemy._on_enemy_presentation_event)
	return {
		"manager": manager,
		"sands": sands,
		"echo": echo,
		"enemy": enemy,
	}


func _production_execution_fixture() -> Dictionary:
	var manager := ProductionEffectBattleManager.new()
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	add_child_autofree(manager)

	var hero := HeroCardScene.instantiate() as HeroCard
	var enemy := EnemyCardScene.instantiate() as EnemyCard
	manager.hero_area.add_child(hero)
	manager.enemy_area.add_child(enemy)
	await get_tree().process_frame

	var hero_stats := ActorStats.new()
	hero_stats.actor_name = "Bound Hero"
	hero_stats.max_hp = 100
	hero_stats.speed = 10
	var hero_model := HeroCombatant.new()
	hero.add_child(hero_model)
	hero_model.setup_base(hero_stats, BattleCombatant.Faction.HERO, manager)
	hero.battle_manager = manager
	hero.bind_combatant(hero_model)

	var enemy_stats := ActorStats.new()
	enemy_stats.actor_name = "Bound Enemy"
	enemy_stats.max_hp = 100
	enemy_stats.attack = 20
	enemy_stats.aim = 100
	enemy_stats.speed = 10
	enemy_stats.starting_guard = 4
	var enemy_model := EnemyCombatant.new()
	enemy.add_child(enemy_model)
	enemy_model.setup_base(enemy_stats, BattleCombatant.Faction.ENEMY, manager)
	enemy.battle_manager = manager
	enemy.bind_combatant(enemy_model)

	var effect := Effect_Damage.new()
	effect.potency = 1.0
	effect.target_type = Action.TargetType.PARENT
	var attack := _action("Bound strike", Action.TargetType.ONE_ENEMY)
	attack.is_attack = true
	attack.effects = [effect]
	var condition := EnemyDecisionCondition.new()
	condition.type = EnemyDecisionCondition.Type.ALWAYS
	var selector := EnemyTargetSelector.new()
	selector.type = EnemyTargetSelector.Type.SEEDED_HERO
	var rule := EnemyDecisionRule.new()
	rule.conditions = [condition]
	rule.selector = selector
	var ability := EnemyAbility.new()
	ability.ability_id = &"bound_strike"
	ability.action = attack
	ability.rules = [rule]
	var enemy_data := EnemyData.new()
	enemy_data.abilities = [ability]
	enemy_data.stats = enemy_stats
	enemy_model.enemy_data = enemy_data
	enemy_model.recover_action = enemy_data.recover_action

	manager.actor_list = [hero, enemy]
	manager.encounter_seed = 77
	return {
		"manager": manager,
		"hero": hero,
		"enemy": enemy,
	}


func _scene_backed_card(scene: PackedScene, card: ActorCard) -> ActorCard:
	var source := scene.instantiate() as ActorCard
	card.damage_popup_scene = source.damage_popup_scene
	card.buff_scene = source.buff_scene
	card.debuff_scene = source.debuff_scene
	while source.get_child_count() > 0:
		var child := source.get_child(0)
		source.remove_child(child)
		_clear_scene_owners(child)
		card.add_child(child)
	source.free()
	return card


func _clear_scene_owners(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		_clear_scene_owners(child)


func _bind_actor(
	card: ActorCard,
	faction: BattleCombatant.Faction,
	actor_name: String,
	priority: int,
	manager: BattleManager,
) -> BattleCombatant:
	var stats := ActorStats.new()
	stats.actor_name = actor_name
	stats.max_hp = 100
	stats.speed = 10
	var model: BattleCombatant = HeroCombatant.new() \
		if faction == BattleCombatant.Faction.HERO else EnemyCombatant.new()
	card.add_child(model)
	model.setup_base(stats, faction, manager)
	model.current_guard = 2
	model.battle_priority = priority
	card.battle_manager = manager
	card.bind_combatant(model)
	return model


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
