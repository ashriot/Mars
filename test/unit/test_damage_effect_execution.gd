extends GutTest

const HeroCardScene := preload("res://src/battle/hero_card.tscn")


class ApplicationFixture extends RefCounted:
	var attacker: ActorCard
	var target: RecordingApplicationTarget
	var effect: Effect_Damage
	var battle_manager: BattleManager


class RecordingApplicationTarget extends ActorCard:
	var recorded_events: Array[Trigger.TriggerType] = []
	var last_damage_context: Dictionary = {}
	var popup_critical_states: Array[bool] = []

	func _spawn_damage_popup(
		_amount: int,
		_damage_type: Action.DamageType,
		is_critical: bool,
	) -> void:
		popup_critical_states.append(is_critical)


class RecordingConditionEffect extends ActionEffect:
	var recording_target: RecordingApplicationTarget
	var recorded_event: Trigger.TriggerType

	func execute(
		_attacker: ActorCard,
		_parent_targets: Array,
		_battle_manager: BattleManager,
		_action: Action = null,
		context: Dictionary = {},
	) -> void:
		recording_target.recorded_events.append(recorded_event)
		recording_target.last_damage_context = context.duplicate(true)


class RecordedHitOutcome extends RefCounted:
	var result: DamageResult
	var results: Array[DamageResult] = []
	var request_builds := 0
	var breach_calls := 0
	var guard_changes: Array[int] = []
	var remaining_guard := 0
	var breached_when_request_built := false
	var rolled_chances: Array[int] = []


class RecordingBattleManager extends BattleManager:
	var event_log: Array[String] = []

	func wait(_duration: float = 0.01) -> void:
		event_log.append("wait")


class ApplicationBattleManager extends BattleManager:
	func _ready() -> void:
		return


class RecordingCombatRandomBattleManager extends RecordingBattleManager:
	var rolled_chances: Array[int] = []
	var random_actor_calls := 0

	func combat_roll_percent(chance: int) -> bool:
		rolled_chances.append(chance)
		return false

	func combat_random_actor(candidates: Array) -> ActorCard:
		random_actor_calls += 1
		return candidates[-1] as ActorCard if not candidates.is_empty() else null


class RecordingActor extends ActorCard:
	var breach_calls := 0
	var guard_changes: Array[int] = []
	var focus_changes: Array[int] = []
	var event_log: Array[String] = []
	var on_hit_contexts: Array[Dictionary] = []

	func modify_guard(amount: int, _is_recovering: bool = false) -> void:
		guard_changes.append(amount)
		current_guard = clampi(current_guard + amount, 0, MAX_GUARD)
		is_in_danger = current_guard == 0 and not is_breached

	func breach() -> void:
		breach_calls += 1
		is_breached = true
		is_in_danger = false

	func shake_panel(_intensity: float = 0.5) -> void:
		return

	func take_one_hit(
		_result: DamageResult,
		_damage_effect: Effect_Damage,
		_attacker: ActorCard,
		_resolved_damage_type: Action.DamageType,
	) -> int:
		return 0

	func take_healing(_heal_amount: int, _is_revive: bool = false) -> void:
		return

	func _fire_condition_event(
		event_type: Trigger.TriggerType,
		context: Dictionary = {},
	) -> void:
		if event_type == Trigger.TriggerType.AFTER_BEING_ATTACKED:
			event_log.append("after")
		elif event_type == Trigger.TriggerType.ON_HIT:
			on_hit_contexts.append(context.duplicate(true))


class RecordingHero extends HeroCard:
	var focus_changes: Array[int] = []
	var focus_contexts: Array[Dictionary] = []

	func modify_focus(amount: int, context: Dictionary = {}) -> void:
		focus_changes.append(amount)
		focus_contexts.append(context.duplicate(true))
		current_focus = clampi(current_focus + amount, 0, 10)


class FocusRefundHero extends HeroCard:
	func update_focus_bar(_animate: bool = true) -> void:
		return

	func _update_conditions_ui() -> void:
		return


class RecordingActionEffect extends ActionEffect:
	var received_contexts: Array[Dictionary] = []
	var received_target_sets: Array = []

	func execute(
		_attacker: ActorCard,
		parent_targets: Array,
		_battle_manager: BattleManager,
		_action: Action = null,
		context: Dictionary = {},
	) -> void:
		received_contexts.append(context.duplicate(true))
		received_target_sets.append(parent_targets.duplicate())


class TargetHpPotencyRule extends DamageScalingRule:
	func resolve(_base_potency: float, context: DamageContext) -> DamageContribution:
		var target_hp := context.target.current_hp if context.target != null else 0
		return DamageContribution.new(
			&"target_hp",
			DamageContribution.Stage.POTENCY,
			float(target_hp) / 1000.0,
		)


class ApplyingDamageEffect extends Effect_Damage:
	var roll_value := 100

	func _roll_percent(chance: int, _battle_manager: BattleManager) -> bool:
		return roll_value <= chance

	func _play_hit_audio() -> void:
		return


class RecordingDamageEffect extends Effect_Damage:
	var forced_damage_type := Action.DamageType.NONE
	var roll_value := 100
	var results: Array[DamageResult] = []
	var request_builds := 0
	var breached_when_request_built := false
	var rolled_chances: Array[int] = []
	var defeat_first_target_after_hit := false
	var first_target: ActorCard
	var clear_attacker_guard_after_first_hit := false
	var battle_manager_to_end_after_hit: BattleManager
	var defeat_attacker_after_hit := false
	var overridden_effect_start_potency := -1.0

	func _resolve_potency(context: DamageContext) -> DamageResolver.ResolvedPotency:
		if overridden_effect_start_potency >= 0.0:
			return DamageResolver.ResolvedPotency.new(
				potency,
				overridden_effect_start_potency,
				[],
			)
		return super._resolve_potency(context)

	func _roll_percent(chance: int, _battle_manager: BattleManager) -> bool:
		rolled_chances.append(chance)
		return roll_value <= chance

	func _pick_random_target(
		candidates: Array,
		_battle_manager: BattleManager,
	) -> ActorCard:
		return candidates[0] as ActorCard if not candidates.is_empty() else null

	func _resolve_forced_damage_type(
		_attacker: ActorCard,
		_target: ActorCard,
		_pre_hit_context: Dictionary,
	) -> Action.DamageType:
		return forced_damage_type

	func _modify_damage_request(
		request: DamageRequest,
		hit_context: DamageContext,
	) -> DamageRequest:
		request_builds += 1
		breached_when_request_built = breached_when_request_built \
			or hit_context.target.is_breached
		return request

	func _play_hit_audio() -> void:
		return

	func _apply_calculated_hit(
		target: ActorCard,
		result: DamageResult,
		attacker: ActorCard,
		_resolved_damage_type: Action.DamageType,
		_is_crit: bool,
	) -> int:
		results.append(result)
		if defeat_first_target_after_hit and target == first_target:
			target.is_defeated = true
		if clear_attacker_guard_after_first_hit and results.size() == 1:
			attacker.current_guard = 0
		if battle_manager_to_end_after_hit != null:
			battle_manager_to_end_after_hit.current_state = BattleManager.State.BATTLE_OVER
		if defeat_attacker_after_hit:
			attacker.is_defeated = true
		return result.final_damage


func test_energy_causes_breach_before_damage_and_same_hit_gets_ovr() -> void:
	var outcome := await _execute_recorded_hit(
		Action.DamageType.ENERGY, 0, false, Action.DamageType.NONE,
		100, 75, 0, 100,
	)
	assert_eq(outcome.breach_calls, 1)
	assert_true(outcome.breached_when_request_built)
	assert_eq(outcome.result.request.overload_power, 75)
	assert_almost_eq(outcome.result.effective_power, 175.0, 0.0001)


func test_intrinsic_and_converted_piercing_never_touch_guard() -> void:
	var intrinsic := await _execute_recorded_hit(
		Action.DamageType.PIERCING, 2, false, Action.DamageType.NONE,
		100, 0, 0, 100,
	)
	var converted := await _execute_recorded_hit(
		Action.DamageType.KINETIC, 2, false, Action.DamageType.PIERCING,
		100, 0, 0, 100,
	)
	assert_eq(intrinsic.guard_changes, [])
	assert_eq(converted.guard_changes, [])
	assert_eq(intrinsic.breach_calls, 0)
	assert_eq(converted.breach_calls, 0)


func test_kinetic_and_energy_always_shred_guard() -> void:
	for resolved_damage_type in [Action.DamageType.KINETIC, Action.DamageType.ENERGY]:
		var outcome := await _execute_recorded_hit(
			resolved_damage_type, 2, false, Action.DamageType.NONE,
			100, 0, 0, 100,
		)
		assert_eq(outcome.guard_changes, [-1])
		assert_eq(outcome.remaining_guard, 1)


func test_take_one_hit_returns_actual_hp_removed_and_lifedrain_excludes_overkill() -> void:
	var fixture := _application_fixture(30, 200)
	var result := DamageCalculator.calculate(_request_for_final_damage(100))
	var actual := await fixture.target.take_one_hit(
		result, fixture.effect, fixture.attacker, Action.DamageType.PIERCING,
	)
	var healing := Effect_Damage.lifedrain_amount(actual, 0.5)
	assert_eq(result.final_damage, 100)
	assert_eq(actual, 30)
	assert_eq(healing, 15)


func test_converted_damage_dispatches_only_resolved_type_event() -> void:
	var fixture := _application_fixture(200, 200)
	var result := DamageCalculator.calculate(_request_for_final_damage(20))
	await fixture.target.take_one_hit(
		result, fixture.effect, fixture.attacker, Action.DamageType.PIERCING,
	)
	assert_false(Trigger.TriggerType.ON_TAKING_KINETIC_DAMAGE in fixture.target.recorded_events)
	assert_false(Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE in fixture.target.recorded_events)
	assert_eq(
		fixture.target.last_damage_context.resolved_damage_type,
		Action.DamageType.PIERCING,
	)


func test_existing_lethal_hit_reaction_order_is_preserved() -> void:
	var fixture := _application_fixture(10, 200)
	var result := DamageCalculator.calculate(_request_for_final_damage(20))
	await fixture.target.take_one_hit(
		result, fixture.effect, fixture.attacker, Action.DamageType.KINETIC,
	)
	assert_eq(fixture.target.recorded_events, [])


func test_zero_pre_critical_remains_explicit_in_result_and_popup() -> void:
	var fixture := _application_fixture(200, 200)
	fixture.attacker.current_stats.attack = 20
	fixture.attacker.current_stats.precision = 0
	var result := _resolved_application_result(fixture, true, false)

	assert_eq(result.request.precision_power, 0)
	assert_true(result.is_critical)
	await fixture.target.take_one_hit(
		result,
		fixture.effect,
		fixture.attacker,
		Action.DamageType.PIERCING,
	)
	assert_eq(fixture.target.popup_critical_states, [true])


func test_zero_ovr_breached_hit_remains_explicit_in_target_event_context() -> void:
	var fixture := _application_fixture(200, 200)
	fixture.attacker.current_stats.attack = 20
	fixture.attacker.current_stats.overload = 0
	var result := _resolved_application_result(fixture, false, true)

	assert_eq(result.request.overload_power, 0)
	assert_true(result.was_breached)
	await fixture.target.take_one_hit(
		result,
		fixture.effect,
		fixture.attacker,
		Action.DamageType.PIERCING,
	)
	assert_true(fixture.target.last_damage_context.was_breached)


func test_damage_source_identity_reaches_target_on_hit_and_attacker_contexts() -> void:
	var fixture := _application_fixture(200, 200)
	var manager := fixture.battle_manager
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	var attacker := _recording_actor(100, 0, 0)
	autofree(attacker)
	manager.actor_list = [attacker, fixture.target]
	var triggered_effect := RecordingActionEffect.new()
	triggered_effect.target_type = Action.TargetType.PARENT
	var trigger := HitTrigger.new()
	trigger.condition = HitTrigger.HitCondition.ALWAYS
	trigger.effects_to_run = [triggered_effect]
	var damage_effect := ApplyingDamageEffect.new()
	damage_effect.damage_type = Action.DamageType.PIERCING
	damage_effect.on_hit_triggers = [trigger]
	var action := Action.new()
	action.effects = [damage_effect]

	await damage_effect.execute(attacker, [fixture.target], manager, action)

	assert_eq(triggered_effect.received_contexts.size(), 1)
	assert_eq(attacker.on_hit_contexts.size(), 1)
	for event_context: Dictionary in [
		fixture.target.last_damage_context,
		triggered_effect.received_contexts[0],
		attacker.on_hit_contexts[0],
	]:
		assert_same(event_context.source_effect, damage_effect)
		assert_same(event_context.source_action, action)
		assert_same(event_context.damage_result.source_effect, damage_effect)
		assert_same(event_context.damage_result.source_action, action)


func test_attacker_on_hit_parent_effect_receives_the_hit_target() -> void:
	var attacker := ActorCard.new()
	attacker.current_stats = ActorStats.new()
	attacker.current_stats.attack = 100
	attacker.current_stats.max_hp = 1000
	attacker.current_hp = 1000
	var target := _recording_actor(0, 0, 0)
	var manager := RecordingBattleManager.new()
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	manager.actor_list = [attacker, target]
	attacker.battle_manager = manager
	var parent_effect := RecordingActionEffect.new()
	parent_effect.target_type = Action.TargetType.PARENT
	var trigger := Trigger.new()
	trigger.trigger_type = Trigger.TriggerType.ON_HIT
	trigger.effects_to_run = [parent_effect]
	var condition := Condition.new()
	condition.condition_name = "Parent hit reaction"
	condition.attacker = attacker
	condition.triggers = [trigger]
	attacker.active_conditions = [condition]
	var damage_effect := RecordingDamageEffect.new()
	damage_effect.damage_type = Action.DamageType.PIERCING

	await damage_effect.execute(attacker, [target], manager)

	assert_eq(parent_effect.received_target_sets.size(), 1)
	assert_eq(parent_effect.received_target_sets[0], [target])
	_free_recorded_nodes(manager, [attacker, target])


func test_production_reverberate_routes_parent_target_and_removes_after_energy_hit() -> void:
	var action := load("res://data/heroes/echo/actions/reverberate.tres") as Action
	var fixture := _application_fixture(200, 200)
	fixture.attacker.current_stats.attack = 5
	fixture.attacker.current_stats.psyche = 40
	fixture.target.current_guard = 1
	fixture.battle_manager.hero_area = Control.new()
	fixture.battle_manager.enemy_area = Control.new()
	fixture.battle_manager.add_child(fixture.battle_manager.hero_area)
	fixture.battle_manager.add_child(fixture.battle_manager.enemy_area)
	fixture.battle_manager.actor_list = [fixture.attacker, fixture.target]
	var condition := (load(
		"res://data/heroes/echo/conditions/reverberate.tres"
	) as Condition).duplicate(true) as Condition
	condition.attacker = fixture.attacker
	var nested_damage := condition.triggers[0].effects_to_run[0] as Effect_Damage
	fixture.target.active_conditions = [
		condition,
		_recording_condition(
			fixture.target,
			fixture.attacker,
			Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE,
		),
	]
	var result := DamageResult.with_hit_facts(
		DamageCalculator.calculate(_request_for_final_damage(10)),
		false,
		false,
		action.effects[0],
		action,
	)

	await fixture.target.take_one_hit(
		result,
		action.effects[0],
		fixture.attacker,
		Action.DamageType.KINETIC,
	)

	assert_eq(fixture.target.current_hp, 130)
	assert_false(fixture.target.has_condition("Reverberate"))
	assert_has(
		fixture.target.recorded_events,
		Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE,
	)
	if not assert_false(fixture.target.last_damage_context.is_empty()):
		return
	assert_eq(
		fixture.target.last_damage_context.resolved_damage_type,
		Action.DamageType.ENERGY,
	)
	assert_same(fixture.target.last_damage_context.source_effect, nested_damage)
	assert_same(fixture.target.last_damage_context.source_action, action)
	assert_same(
		fixture.target.last_damage_context.damage_result.source_effect,
		nested_damage,
	)


func test_nested_damage_inherits_source_action_for_its_own_damage_contexts() -> void:
	var fixture := _application_fixture(300, 300)
	var manager := fixture.battle_manager
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	var attacker := _recording_actor(100, 0, 0)
	autofree(attacker)
	manager.actor_list = [attacker, fixture.target]
	var nested_damage := ApplyingDamageEffect.new()
	nested_damage.damage_type = Action.DamageType.PIERCING
	nested_damage.target_type = Action.TargetType.PARENT
	var trigger := HitTrigger.new()
	trigger.condition = HitTrigger.HitCondition.ALWAYS
	trigger.effects_to_run = [nested_damage]
	var outer_damage := ApplyingDamageEffect.new()
	outer_damage.damage_type = Action.DamageType.PIERCING
	outer_damage.on_hit_triggers = [trigger]
	var action := Action.new()
	action.effects = [outer_damage]

	await outer_damage.execute(attacker, [fixture.target], manager, action)

	assert_same(fixture.target.last_damage_context.source_effect, nested_damage)
	assert_same(fixture.target.last_damage_context.source_action, action)
	assert_same(
		fixture.target.last_damage_context.damage_result.source_action,
		action,
	)
	assert_eq(attacker.on_hit_contexts.size(), 2)
	assert_same(attacker.on_hit_contexts[0].source_effect, nested_damage)
	assert_same(attacker.on_hit_contexts[0].source_action, action)


func test_aim_is_clamped_at_roll_boundary() -> void:
	var below := await _execute_recorded_hit(
		Action.DamageType.PIERCING, 0, false, Action.DamageType.NONE,
		100, 0, -50, 1,
	)
	var above := await _execute_recorded_hit(
		Action.DamageType.PIERCING, 0, false, Action.DamageType.NONE,
		100, 0, 150, 100,
	)
	assert_eq(below.rolled_chances, [0])
	assert_eq(above.rolled_chances, [100])
	assert_eq(below.result.request.precision_power, 0)
	assert_gt(above.result.request.precision_power, 0)


func test_critical_and_random_target_rolls_use_battle_manager_rng() -> void:
	var attacker := _recording_actor(100, 0, 0)
	attacker.current_stats.aim = 37
	var first_target := _recording_actor(0, 0, 0)
	var second_target := _recording_actor(0, 0, 0)
	var manager := RecordingCombatRandomBattleManager.new()
	manager.actor_list = [attacker, first_target, second_target]
	var action := Action.new()
	action.target_type = Action.TargetType.RANDOM_ENEMY
	var effect := Effect_Damage.new()
	effect.damage_type = Action.DamageType.PIERCING

	await effect.execute(
		attacker,
		[first_target, second_target],
		manager,
		action,
	)

	assert_eq(manager.random_actor_calls, 1)
	assert_eq(manager.rolled_chances, [37])
	_free_recorded_nodes(manager, [attacker, first_target, second_target])


func test_asymmetric_psyche_power_matches_runtime_and_preview() -> void:
	var attacker := _recording_actor(10, 20, 0)
	attacker.current_stats.psyche = 100
	attacker.current_stats.precision = 30
	attacker.current_stats.aim = 100
	var target := _recording_actor(0, 0, 0)
	target.is_breached = true
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, target]
	var effect := RecordingDamageEffect.new()
	effect.power_type = Action.PowerType.PSYCHE
	effect.damage_type = Action.DamageType.PIERCING
	effect.roll_value = 1
	var action := Action.new()
	action.effects = [effect]
	var preview := DamagePreview.for_effect(
		effect, attacker, target, action, 1, true,
	)

	await effect.execute(attacker, [target], manager, action)

	assert_eq(effect.results.size(), 1)
	var runtime := effect.results[0]
	assert_eq(preview.request.base_power, 100)
	assert_eq(runtime.request.base_power, 100)
	assert_almost_eq(preview.effective_power, 150.0, 0.0001)
	assert_almost_eq(runtime.effective_power, 150.0, 0.0001)
	assert_eq(runtime.final_damage, preview.final_damage)
	_free_recorded_nodes(manager, [attacker, target])


func test_each_planned_hit_builds_one_request_and_result() -> void:
	var attacker := _recording_actor(100, 0, 0)
	var target := _recording_actor(0, 0, 0)
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, target]
	var effect := RecordingDamageEffect.new()
	effect.damage_type = Action.DamageType.PIERCING
	effect.hit_count = 3

	await effect.execute(attacker, [target], manager)

	assert_eq(effect.request_builds, 3)
	assert_eq(effect.results.size(), 3)
	_free_recorded_nodes(manager, [attacker, target])


func test_production_inversion_context_builds_three_canonical_results() -> void:
	var attacker := _recording_actor(10, 0, 0)
	attacker.current_stats.psyche = 80
	var target := _recording_actor(0, 0, 0)
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, target]
	var inversion := (load(
		"res://data/heroes/echo/conditions/inversion.tres"
	) as Condition).duplicate(true) as Condition
	var effect := inversion.triggers[0].effects_to_run[0] as Effect_Damage_Inversion

	await effect.execute(
		attacker, [target], manager, null, {"guard_gained": 3},
	)

	assert_eq(attacker.on_hit_contexts.size(), 3)
	var result_ids: Dictionary = {}
	var request_ids: Dictionary = {}
	for hit_context: Dictionary in attacker.on_hit_contexts:
		assert_true(hit_context.damage_result is DamageResult)
		var result := hit_context.damage_result as DamageResult
		result_ids[result.get_instance_id()] = true
		request_ids[result.request.get_instance_id()] = true
		assert_same(result.source_effect, effect)
		assert_eq(result.request.distribution_count, 1)
		assert_eq(result.request.damage_type, Action.DamageType.PIERCING)
	assert_eq(result_ids.size(), 3)
	assert_eq(request_ids.size(), 3)
	_free_recorded_nodes(manager, [attacker, target])


func test_empty_context_attacker_buff_trigger_counts_buffs_not_debuffs() -> void:
	assert_eq(await _empty_context_buff_trigger_count(Condition.ConditionType.BUFF), 1)
	assert_eq(await _empty_context_buff_trigger_count(Condition.ConditionType.DEBUFF), 0)


func test_vulnerable_or_breached_hit_trigger_skips_normal_targets() -> void:
	var attacker := _recording_actor(100, 0, 0)
	var vulnerable := _recording_actor(0, 0, 0)
	var breached := _recording_actor(0, 0, 0)
	var normal := _recording_actor(0, 0, 0)
	vulnerable.is_in_danger = true
	breached.is_breached = true
	var manager := RecordingBattleManager.new()
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	manager.actor_list = [attacker, vulnerable, breached, normal]
	var recording_effect := RecordingActionEffect.new()
	var trigger := HitTrigger.new()
	trigger.condition = HitTrigger.HitCondition.IF_TARGET_IS_VULNERABLE_OR_BREACHED
	trigger.effects_to_run = [recording_effect]
	var damage_effect := Effect_Damage.new()
	damage_effect.on_hit_triggers = [trigger]

	for target: ActorCard in [vulnerable, breached, normal]:
		await damage_effect._process_on_hit_triggers(attacker, target, manager, {})

	assert_eq(recording_effect.received_target_sets, [[vulnerable], [breached]])
	_free_recorded_nodes(manager, [attacker, vulnerable, breached, normal])


func test_effect_start_potency_is_stable_across_hits() -> void:
	var attacker := _recording_actor(100, 0, 2)
	var target := _recording_actor(0, 0, 0)
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, target]
	var rule := DamageScalingFlatPerResource.new()
	rule.resource = DamageScalingFlatPerResource.ResourceType.GUARD
	rule.potency_per_point = 1.0
	var effect := RecordingDamageEffect.new()
	effect.damage_type = Action.DamageType.PIERCING
	effect.potency = 0.0
	effect.hit_count = 2
	effect.scaling_rules = [rule]
	effect.clear_attacker_guard_after_first_hit = true

	await effect.execute(attacker, [target], manager)

	assert_eq(effect.results.size(), 2)
	assert_eq(effect.results[0].request.potency, 2.0)
	assert_eq(effect.results[1].request.potency, 2.0)
	_free_recorded_nodes(manager, [attacker, target])


func test_current_hit_scaling_uses_each_exact_target_snapshot() -> void:
	var attacker := _recording_actor(100, 0, 0)
	var first_target := _recording_actor(0, 0, 0)
	var second_target := _recording_actor(0, 0, 0)
	first_target.current_hp = 250
	second_target.current_hp = 750
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, first_target, second_target]
	var rule := TargetHpPotencyRule.new()
	rule.phase = DamageScalingRule.Phase.CURRENT_HIT
	var effect := RecordingDamageEffect.new()
	effect.damage_type = Action.DamageType.PIERCING
	effect.potency = 1.0
	effect.scaling_rules = [rule]

	await effect.execute(attacker, [first_target, second_target], manager)

	assert_eq(effect.results.size(), 2)
	assert_almost_eq(effect.results[0].request.potency, 1.25, 0.0001)
	assert_almost_eq(effect.results[1].request.potency, 1.75, 0.0001)
	assert_eq(effect.results[0].request.contributions[0].source, &"target_hp")
	assert_eq(effect.results[1].request.contributions[0].source, &"target_hp")
	_free_recorded_nodes(manager, [attacker, first_target, second_target])


func test_phase_composition_preserves_custom_effect_start_potency_hook() -> void:
	var attacker := _recording_actor(100, 0, 0)
	var target := _recording_actor(0, 0, 0)
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, target]
	var effect := RecordingDamageEffect.new()
	effect.damage_type = Action.DamageType.PIERCING
	effect.potency = 1.0
	effect.overridden_effect_start_potency = 2.5
	var action := Action.new()
	action.effects = [effect]

	var preview := DamagePreview.for_effect(
		effect,
		attacker,
		target,
		action,
		1,
		false,
	)
	await effect.execute(attacker, [target], manager, action)

	assert_almost_eq(preview.request.potency, 2.5, 0.0001)
	assert_eq(effect.results.size(), 1)
	assert_almost_eq(effect.results[0].request.potency, 2.5, 0.0001)
	_free_recorded_nodes(manager, [attacker, target])


func test_phase_composition_clamps_once_after_negative_and_positive_rules() -> void:
	var attacker := _recording_actor(100, 0, 1)
	var target := _recording_actor(0, 0, 0)
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, target]
	var effect_start_rule := DamageScalingFlatPerResource.new()
	effect_start_rule.resource = DamageScalingFlatPerResource.ResourceType.GUARD
	effect_start_rule.potency_per_point = -2.0
	var current_hit_rule := DamageScalingFlatPerResource.new()
	current_hit_rule.resource = DamageScalingFlatPerResource.ResourceType.GUARD
	current_hit_rule.potency_per_point = 2.0
	current_hit_rule.phase = DamageScalingRule.Phase.CURRENT_HIT
	var effect := RecordingDamageEffect.new()
	effect.damage_type = Action.DamageType.PIERCING
	effect.potency = 1.0
	effect.scaling_rules = [effect_start_rule, current_hit_rule]
	var action := Action.new()
	action.effects = [effect]

	var preview := DamagePreview.for_effect(
		effect,
		attacker,
		target,
		action,
		1,
		false,
	)
	await effect.execute(attacker, [target], manager, action)

	assert_almost_eq(preview.request.potency, 1.0, 0.0001)
	assert_eq(effect.results.size(), 1)
	assert_almost_eq(effect.results[0].request.potency, 1.0, 0.0001)
	assert_eq(effect.results[0].request.contributions.size(), 2)
	_free_recorded_nodes(manager, [attacker, target])


func test_random_split_keeps_initial_divisor_after_target_defeat() -> void:
	var attacker := _recording_actor(100, 0, 0)
	var first_target := _recording_actor(0, 0, 0)
	var second_target := _recording_actor(0, 0, 0)
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, first_target, second_target]
	var action := Action.new()
	action.target_type = Action.TargetType.RANDOM_ENEMY
	var effect := RecordingDamageEffect.new()
	effect.damage_type = Action.DamageType.PIERCING
	effect.hit_count = 3
	effect.split_damage = true
	effect.first_target = first_target
	effect.defeat_first_target_after_hit = true

	await effect.execute(attacker, [first_target, second_target], manager, action)

	assert_eq(effect.results.size(), 3)
	for result in effect.results:
		assert_eq(result.request.distribution_count, 3)
	_free_recorded_nodes(manager, [attacker, first_target, second_target])


func test_early_lethal_nonrandom_hit_waits_before_after_attacked_event() -> void:
	assert_eq(await _early_lethal_nonrandom_event_log(), ["wait", "after"])


func test_early_lethal_nonrandom_hit_stops_after_wait_when_battle_ends() -> void:
	assert_eq(await _early_lethal_nonrandom_event_log(&"battle_over"), ["wait"])


func test_early_lethal_nonrandom_hit_stops_after_wait_when_attacker_is_defeated() -> void:
	assert_eq(await _early_lethal_nonrandom_event_log(&"attacker_defeated"), ["wait"])


func _early_lethal_nonrandom_event_log(
	terminal_state_after_hit: StringName = &"",
) -> Array[String]:
	var attacker := _recording_actor(100, 0, 0)
	var target := _recording_actor(0, 0, 0)
	var event_log: Array[String] = []
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, target]
	manager.event_log = event_log
	target.event_log = event_log
	var effect := RecordingDamageEffect.new()
	effect.damage_type = Action.DamageType.PIERCING
	effect.hit_count = 2
	effect.first_target = target
	effect.defeat_first_target_after_hit = true
	if terminal_state_after_hit == &"battle_over":
		effect.battle_manager_to_end_after_hit = manager
	elif terminal_state_after_hit == &"attacker_defeated":
		effect.defeat_attacker_after_hit = true

	await effect.execute(attacker, [target], manager)

	assert_eq(effect.results.size(), 1)
	_free_recorded_nodes(manager, [attacker, target])
	return event_log


func test_execute_action_pays_scaled_focus_once_and_passes_cost_context() -> void:
	var manager := _recording_action_manager()
	var hero := RecordingHero.new()
	hero.current_stats = ActorStats.new()
	hero.current_focus = 10
	var discount := Condition.new()
	discount.focus_cost_reduction = 0.5
	hero.active_conditions = [discount]
	var capture_effect := RecordingActionEffect.new()
	var action := Action.new()
	action.action_name = "Discounted"
	action.focus_cost = 4
	action.effects = [capture_effect]

	await manager.execute_action(hero, action, [hero], false)

	assert_eq(hero.focus_changes, [-2])
	assert_eq(hero.focus_contexts.size(), 1)
	assert_eq(hero.focus_contexts[0].paid_focus_cost, 2)
	assert_same(hero.focus_contexts[0].action, action)
	assert_eq(hero.current_focus, 8)
	assert_eq(capture_effect.received_contexts.size(), 1)
	assert_eq(capture_effect.received_contexts[0].paid_focus_cost, 2)
	manager.free()
	hero.free()


func test_free_action_consumes_refund_before_later_paid_action() -> void:
	var manager := _recording_action_manager()
	var hero := FocusRefundHero.new()
	hero.current_stats = ActorStats.new()
	hero.current_focus = 5
	var refund := Condition.new()
	refund.condition_name = "Coordinate"
	refund.refund_focus_cost_on_spend = true
	refund.remove_on_triggers = [Trigger.TriggerType.ON_SPENDING_FOCUS]
	hero.active_conditions = [refund]
	var free_action := Action.new()
	free_action.action_name = "Free setup"
	free_action.focus_cost = 0
	var paid_action := Action.new()
	paid_action.action_name = "Later paid action"
	paid_action.focus_cost = 3

	await manager.execute_action(hero, free_action, [hero], false)

	assert_eq(hero.current_focus, 5)
	assert_false(hero.active_conditions.has(refund))
	await manager.execute_action(hero, paid_action, [hero], false)
	assert_eq(hero.current_focus, 2)
	manager.free()
	hero.free()


func test_execute_action_rejects_insufficient_scaled_focus_before_effects() -> void:
	var manager := _recording_action_manager()
	var hero := RecordingHero.new()
	hero.current_stats = ActorStats.new()
	hero.current_focus = 1
	var capture_effect := RecordingActionEffect.new()
	var action := Action.new()
	action.action_name = "Too Expensive"
	action.focus_cost = 2
	action.effects = [capture_effect]

	await manager.execute_action(hero, action, [hero], false)

	assert_eq(hero.focus_changes, [])
	assert_eq(hero.current_focus, 1)
	assert_eq(capture_effect.received_contexts, [])
	manager.free()
	hero.free()


func _execute_recorded_hit(
	damage_type: Action.DamageType,
	guard: int,
	is_breached: bool,
	forced_damage_type: Action.DamageType,
	base_power: int,
	overload: int,
	aim: int,
	roll_value: int,
) -> RecordedHitOutcome:
	var attacker := _recording_actor(base_power, overload, 0)
	attacker.current_stats.aim = aim
	attacker.current_stats.precision = 100
	var target := _recording_actor(0, 0, guard)
	target.is_breached = is_breached
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, target]
	var effect := RecordingDamageEffect.new()
	effect.damage_type = damage_type
	effect.forced_damage_type = forced_damage_type
	effect.roll_value = roll_value

	await effect.execute(attacker, [target], manager)

	var outcome := RecordedHitOutcome.new()
	outcome.results = effect.results.duplicate()
	outcome.result = effect.results[0] if not effect.results.is_empty() else null
	outcome.request_builds = effect.request_builds
	outcome.breach_calls = target.breach_calls
	outcome.guard_changes = target.guard_changes.duplicate()
	outcome.remaining_guard = target.current_guard
	outcome.breached_when_request_built = effect.breached_when_request_built
	outcome.rolled_chances = effect.rolled_chances.duplicate()
	_free_recorded_nodes(manager, [attacker, target])
	return outcome


func _recording_actor(base_power: int, overload: int, guard: int) -> RecordingActor:
	var actor := RecordingActor.new()
	actor.current_stats = ActorStats.new()
	actor.current_stats.attack = base_power
	actor.current_stats.psyche = base_power
	actor.current_stats.overload = overload
	actor.current_stats.max_hp = 1000
	actor.current_hp = 1000
	actor.current_guard = guard
	return actor


func _application_fixture(hp: int, max_hp: int) -> ApplicationFixture:
	var scene_card := HeroCardScene.instantiate() as ActorCard
	_clear_scene_owners(scene_card)
	var target := RecordingApplicationTarget.new()
	target.damage_popup_scene = scene_card.damage_popup_scene
	target.buff_scene = scene_card.buff_scene
	target.debuff_scene = scene_card.debuff_scene
	while scene_card.get_child_count() > 0:
		var child := scene_card.get_child(0)
		scene_card.remove_child(child)
		target.add_child(child)
	scene_card.free()
	add_child_autofree(target)

	var battle_manager := ApplicationBattleManager.new()
	battle_manager.battle_speed = 1.0
	add_child_autofree(battle_manager)
	target.battle_manager = battle_manager
	target.current_stats = ActorStats.new()
	target.current_stats.max_hp = max_hp
	target.current_hp = hp
	target.current_guard = 0
	target.update_health_bar()

	var attacker := HeroCardScene.instantiate() as ActorCard
	add_child_autofree(attacker)
	attacker.current_stats = ActorStats.new()
	var effect := Effect_Damage.new()
	effect.damage_type = Action.DamageType.KINETIC
	for event_type in [
		Trigger.TriggerType.ON_TAKING_KINETIC_DAMAGE,
		Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE,
		Trigger.TriggerType.ON_BEING_HIT,
	]:
		target.active_conditions.append(_recording_condition(target, attacker, event_type))

	var fixture := ApplicationFixture.new()
	fixture.attacker = attacker
	fixture.target = target
	fixture.effect = effect
	fixture.battle_manager = battle_manager
	return fixture


func _clear_scene_owners(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_scene_owners(child)


func _recording_condition(
	target: RecordingApplicationTarget,
	attacker: ActorCard,
	event_type: Trigger.TriggerType,
) -> Condition:
	var effect := RecordingConditionEffect.new()
	effect.recording_target = target
	effect.recorded_event = event_type
	effect.target_type = Action.TargetType.SELF
	var trigger := Trigger.new()
	trigger.trigger_type = event_type
	trigger.effects_to_run = [effect]
	var condition := Condition.new()
	condition.attacker = attacker
	condition.triggers = [trigger]
	return condition


func _request_for_final_damage(amount: int) -> DamageRequest:
	return DamageRequest.new(
		amount,
		0,
		0,
		1.0,
		1,
		Action.DamageType.PIERCING,
		0,
		0.0,
		0.0,
	)


func _resolved_application_result(
	fixture: ApplicationFixture,
	is_critical: bool,
	is_breached: bool,
) -> DamageResult:
	fixture.target.is_breached = is_breached
	var action := Action.new()
	var hit_context := DamageContext.capture(
		fixture.attacker,
		fixture.target,
		fixture.battle_manager,
		action,
		fixture.effect,
	)
	return DamageResolver.resolve_hit(
		fixture.attacker,
		fixture.target,
		Action.PowerType.ATTACK,
		DamageResolver.resolve_potency(1.0, [], hit_context),
		1,
		Action.DamageType.PIERCING,
		is_critical,
		hit_context,
	)


func _recording_action_manager() -> RecordingBattleManager:
	var manager := RecordingBattleManager.new()
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.current_action_panel = PanelContainer.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	manager.add_child(manager.current_action_panel)
	return manager


func _empty_context_buff_trigger_count(condition_type: Condition.ConditionType) -> int:
	var attacker := _recording_actor(100, 0, 0)
	var target := _recording_actor(0, 0, 0)
	var condition := Condition.new()
	condition.condition_type = condition_type
	attacker.active_conditions = [condition]
	var manager := RecordingBattleManager.new()
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	manager.actor_list = [attacker, target]
	var recording_effect := RecordingActionEffect.new()
	var trigger := HitTrigger.new()
	trigger.condition = HitTrigger.HitCondition.IF_ATTACKER_HAS_BUFF
	trigger.effects_to_run = [recording_effect]
	var damage_effect := Effect_Damage.new()
	damage_effect.on_hit_triggers = [trigger]

	await damage_effect._process_on_hit_triggers(attacker, target, manager, {})

	var count := recording_effect.received_contexts.size()
	_free_recorded_nodes(manager, [attacker, target])
	return count


func _free_recorded_nodes(manager: BattleManager, actors: Array) -> void:
	manager.free()
	for actor in actors:
		actor.free()
