extends GutTest

const CardSceneTestFixture := preload("res://test/helpers/card_scene_test_fixture.gd")

const HeroCardScene := preload("res://src/battle/hero_card.tscn")


class ApplicationFixture extends RefCounted:
	var attacker: ActorCard
	var target: RecordingApplicationTarget
	var effect: Effect_Damage
	var battle_manager: BattleManager


class IntCounter extends RefCounted:
	var value := 0


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
		_attacker: Node,
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

	func combat_random_actor(candidates: Array) -> Node:
		random_actor_calls += 1
		return candidates[-1] as Node if not candidates.is_empty() else null


class RecordingActor extends BattleCombatant:
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

	func take_one_hit(
		_result: DamageResult,
		_damage_effect: Effect_Damage,
		_attacker: Node,
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
		var model := combatant as HeroCombatant
		model.current_focus = clampi(model.current_focus + amount, 0, 10)


class FocusRefundHero extends HeroCard:
	func update_focus_bar(_animate: bool = true) -> void:
		return

	func _update_conditions_ui() -> void:
		return


class EchoRuntimeHero extends HeroCombatant:
	var healing_events: Array[int] = []
	var guard_changes: Array[int] = []

	func take_healing(amount: int, is_revive: bool = false) -> void:
		if (is_defeated and not is_revive) or amount <= 0:
			return
		healing_events.append(amount)
		current_hp = mini(current_hp + amount, current_stats.max_hp)

	func modify_guard(amount: int, is_recovering: bool = false) -> void:
		guard_changes.append(amount)
		current_guard = clampi(current_guard + amount, 0, MAX_GUARD)
		if amount > 0 and not is_recovering:
			await _fire_condition_event(
				Trigger.TriggerType.ON_GAINING_GUARD,
				{"targets": [self], "guard_gained": amount},
			)


class EchoRuntimeEnemy extends EnemyCombatant:
	var damage_results: Array[DamageResult] = []
	var guard_changes: Array[int] = []

	func take_one_hit(
		result: DamageResult,
		_damage_effect: Effect_Damage,
		_attacker: Node,
		_resolved_damage_type: Action.DamageType,
	) -> int:
		damage_results.append(result)
		var removed := mini(current_hp, result.final_damage)
		current_hp -= removed
		return removed

	func modify_guard(amount: int, is_recovering: bool = false) -> void:
		guard_changes.append(amount)
		current_guard = clampi(current_guard + amount, 0, MAX_GUARD)
		if amount > 0 and not is_recovering:
			await _fire_condition_event(
				Trigger.TriggerType.ON_GAINING_GUARD,
				{"targets": [self], "guard_gained": amount},
			)


class RecordingActionEffect extends ActionEffect:
	var received_contexts: Array[Dictionary] = []
	var received_target_sets: Array = []

	func execute(
		_attacker: Node,
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


class DefeatingOnHitLifedrainEffect extends ApplyingDamageEffect:
	func _process_on_hit_triggers(
		attacker: BattleCombatant,
		_target: BattleCombatant,
		_battle_manager: BattleManager,
		_context: Dictionary,
	) -> void:
		attacker.current_hp = 0
		attacker.is_defeated = true


class RecordingDamageEffect extends Effect_Damage:
	var forced_damage_type := Action.DamageType.NONE
	var roll_value := 100
	var results: Array[DamageResult] = []
	var request_builds := 0
	var breached_when_request_built := false
	var rolled_chances: Array[int] = []
	var defeat_first_target_after_hit := false
	var first_target: BattleCombatant
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
	) -> BattleCombatant:
		return candidates[0] as BattleCombatant if not candidates.is_empty() else null

	func _resolve_forced_damage_type(
		_attacker: BattleCombatant,
		_target: BattleCombatant,
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
		target: BattleCombatant,
		result: DamageResult,
		attacker: BattleCombatant,
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


func test_lifedrain_cannot_revive_an_attacker_defeated_by_hit_reaction() -> void:
	var manager := ApplicationBattleManager.new()
	manager.battle_speed = 1.0
	add_child_autofree(manager)
	var attacker := CardSceneTestFixture.bind(
		self, FocusRefundHero.new(), BattleCombatant.Faction.HERO, null, manager,
	) as FocusRefundHero
	attacker.current_stats = ActorStats.new()
	attacker.current_stats.attack = 100
	attacker.current_stats.max_hp = 100
	attacker.current_hp = 50
	attacker.battle_manager = manager
	var target := EchoRuntimeEnemy.new()
	var target_stats := ActorStats.new()
	target_stats.max_hp = 100
	target.setup_base(target_stats, BattleCombatant.Faction.ENEMY, manager)
	manager.actor_list = [attacker, target]
	var effect := DefeatingOnHitLifedrainEffect.new()
	effect.damage_type = Action.DamageType.PIERCING
	effect.lifedrain_scalar = 1.0

	await effect.execute(attacker, [target], manager)

	assert_true(attacker.is_defeated)
	assert_eq(attacker.current_hp, 0)
	attacker.free()
	target.free()


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


func test_lethal_hit_fires_reactions_then_enforces_one_defeat() -> void:
	var fixture := _application_fixture(10, 200)
	var defeat_count := _track_defeats(fixture.target)
	fixture.attacker.current_stats.attack = 20
	fixture.attacker.current_stats.aim = 0
	fixture.target.current_stats.psyche = 20
	fixture.target.is_breached = true
	var self_heal := Effect_Healing.new()
	self_heal.potency = 1.0
	self_heal.target_type = Action.TargetType.SELF
	var heal_trigger := Trigger.new()
	heal_trigger.trigger_type = Trigger.TriggerType.ON_BEING_HIT
	heal_trigger.effects_to_run = [self_heal]
	var heal_condition := Condition.new()
	heal_condition.attacker = fixture.target
	heal_condition.triggers = [heal_trigger]
	fixture.target.active_conditions.append(heal_condition)
	var effect := _applying_damage(Action.DamageType.KINETIC)

	await effect.execute(
		fixture.attacker, [fixture.target], fixture.battle_manager,
	)

	assert_eq(fixture.target.recorded_events, [
		Trigger.TriggerType.ON_TAKING_KINETIC_DAMAGE,
		Trigger.TriggerType.ON_BEING_HIT,
	])
	assert_eq(fixture.target.current_hp, 0)
	assert_true(fixture.target.is_defeated)
	assert_eq(defeat_count.value, 1)


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
	var attacker := CardSceneTestFixture.actor(self)
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
	attacker.combatant.battle_manager = manager
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

	assert_eq(fixture.target.current_hp, 110)
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


func test_lethal_kinetic_hit_triggers_production_reverberate_once() -> void:
	var fixture := _application_fixture(10, 200)
	var defeat_count := _track_defeats(fixture.target)
	fixture.attacker.current_stats.attack = 20
	fixture.attacker.current_stats.aim = 0
	fixture.target.is_breached = true
	var echo := _application_party_hero(
		fixture.battle_manager, "Echo", 100, 40, 200, 200,
	)
	var reverberate := _production_condition(
		"res://data/heroes/echo/conditions/reverberate.tres", echo,
	)
	fixture.target.active_conditions.append(reverberate)
	var effect := _applying_damage(Action.DamageType.KINETIC)

	await effect.execute(
		fixture.attacker, [fixture.target], fixture.battle_manager,
	)

	assert_false(fixture.target.has_condition("Reverberate"))
	assert_eq(fixture.target.recorded_events.count(
		Trigger.TriggerType.ON_TAKING_KINETIC_DAMAGE
	), 1)
	assert_eq(fixture.target.recorded_events.count(
		Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE
	), 1)
	assert_eq(fixture.target.recorded_events.count(
		Trigger.TriggerType.ON_BEING_HIT
	), 2)
	assert_eq(fixture.target.popup_critical_states.size(), 2)
	assert_true(fixture.target.is_defeated)
	assert_eq(fixture.target.current_hp, 0)
	assert_eq(defeat_count.value, 1)


func test_lethal_incoming_hit_triggers_energy_barrier_retaliation_once() -> void:
	var fixture := _application_fixture(10, 200)
	var defeat_count := _track_defeats(fixture.target)
	var incoming_attacker := _application_target(
		fixture.battle_manager, 1000, 1000,
	)
	_configure_application_actor(
		incoming_attacker, "Incoming Attacker", 20, 5, 1000, 1000,
	)
	incoming_attacker.is_breached = true
	var echo := _application_party_hero(
		fixture.battle_manager, "Echo", 100, 40, 200, 200,
	)
	var barrier := _production_condition(
		"res://data/heroes/echo/conditions/energy_barrier.tres", echo,
	)
	fixture.target.active_conditions.append(barrier)
	var effect := _applying_damage(Action.DamageType.PIERCING)

	await effect.execute(
		incoming_attacker, [fixture.target], fixture.battle_manager,
	)

	assert_eq(incoming_attacker.current_hp, 940)
	assert_false(fixture.target.has_condition("Energy Barrier"))
	assert_eq(fixture.target.recorded_events.count(
		Trigger.TriggerType.ON_BEING_HIT
	), 1)
	assert_true(fixture.target.is_defeated)
	assert_eq(fixture.target.current_hp, 0)
	assert_eq(defeat_count.value, 1)


func test_lethal_incoming_hit_triggers_pain_transfer_for_living_party_once() -> void:
	var fixture := _application_fixture(10, 200)
	var defeat_count := _track_defeats(fixture.target)
	fixture.attacker.reparent(fixture.battle_manager.hero_area)
	_configure_application_actor(fixture.attacker, "Ally", 20, 5, 100, 50)
	var echo := _application_party_hero(
		fixture.battle_manager, "Echo", 100, 40, 100, 50,
	)
	var defeated_ally := _application_party_hero(
		fixture.battle_manager, "Defeated Ally", 20, 5, 100, 0, true,
	)
	var pain_transfer := _production_condition(
		"res://data/heroes/echo/conditions/pain_transfer.tres", echo,
	)
	fixture.target.active_conditions.append(pain_transfer)
	var effect := _applying_damage(Action.DamageType.PIERCING)

	await effect.execute(
		fixture.attacker, [fixture.target], fixture.battle_manager,
	)

	assert_eq(echo.current_hp, 70)
	assert_eq(fixture.attacker.current_hp, 70)
	assert_eq(defeated_ally.current_hp, 0)
	assert_true(defeated_ally.is_defeated)
	assert_eq(fixture.target.recorded_events.count(
		Trigger.TriggerType.ON_BEING_HIT
	), 1)
	assert_true(fixture.target.is_defeated)
	assert_eq(fixture.target.current_hp, 0)
	assert_eq(defeat_count.value, 1)


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


func test_percent_guard_removal_rounds_up_and_caps() -> void:
	var effect := Effect_ModifyGuard.new()
	effect.percent_change = -0.5
	effect.max_abs_change = 5

	assert_eq(effect.resolve_guard_delta(3), -2)
	assert_eq(effect.resolve_guard_delta(20), -5)


func test_zero_max_abs_guard_change_is_uncapped() -> void:
	var effect := Effect_ModifyGuard.new()
	effect.percent_change = -0.5
	effect.max_abs_change = 0

	assert_eq(effect.resolve_guard_delta(20), -10)


func test_inversion_caps_guard_points_available_to_destroy() -> void:
	var effect := Effect_Damage_Inversion.new()
	effect.max_guard_points = 4

	assert_eq(effect.resolve_guard_points(2), 2)
	assert_eq(effect.resolve_guard_points(6), 4)


func test_zero_max_inversion_guard_points_is_uncapped() -> void:
	var effect := Effect_Damage_Inversion.new()
	effect.max_guard_points = 0

	assert_eq(effect.resolve_guard_points(14), 14)


func test_production_inversion_builds_one_scaled_result_from_guard_destroyed() -> void:
	var attacker := _recording_actor(10, 0, 0)
	attacker.current_stats.psyche = 80
	var target := _recording_actor(0, 0, 0)
	target.current_guard = 3
	var manager := RecordingBattleManager.new()
	manager.actor_list = [attacker, target]
	var inversion := load("res://data/heroes/echo/actions/inversion.tres") as Action
	var effect := inversion.effects[0] as Effect_Damage_Inversion

	await effect.execute(attacker, [target], manager, inversion)

	assert_eq(target.guard_changes, [-3])
	assert_eq(target.current_guard, 0)
	assert_eq(attacker.on_hit_contexts.size(), 1)
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
		assert_almost_eq(result.request.base_potency, 0.75, 0.0001)
		assert_almost_eq(result.request.potency, 2.25, 0.0001)
	assert_eq(result_ids.size(), 1)
	assert_eq(request_ids.size(), 1)
	_free_recorded_nodes(manager, [attacker, target])


func test_production_feedback_reacts_per_hit_then_expires_after_attack() -> void:
	var fixture := _echo_runtime_fixture()
	var echo := fixture.echo as EchoRuntimeHero
	var enemy := fixture.enemy as EchoRuntimeEnemy
	enemy.current_guard = 3
	var feedback := (load(
		"res://data/heroes/echo/conditions/feedback.tres"
	) as Condition).duplicate(true) as Condition
	feedback.attacker = echo
	enemy.active_conditions = [feedback]

	await enemy._fire_condition_event(Trigger.TriggerType.ON_HIT)
	await enemy._fire_condition_event(Trigger.TriggerType.ON_HIT)

	assert_eq(enemy.current_guard, 1)
	assert_eq(enemy.guard_changes, [-1, -1])
	assert_eq(enemy.damage_results.size(), 2)
	for result: DamageResult in enemy.damage_results:
		assert_eq(result.final_damage, 20)
		assert_eq(result.request.damage_type, Action.DamageType.PIERCING)
	assert_true(enemy.has_condition("Feedback"))

	await enemy._fire_condition_event(Trigger.TriggerType.AFTER_ATTACKING)

	assert_false(enemy.has_condition("Feedback"))
	_free_echo_runtime_fixture(fixture)


func test_production_pain_transfer_heals_living_party_per_hit_until_echo_turn() -> void:
	var fixture := _echo_runtime_fixture(true)
	var manager := fixture.manager as RecordingBattleManager
	var echo := fixture.echo as EchoRuntimeHero
	var ally := fixture.ally as EchoRuntimeHero
	var defeated := fixture.defeated as EchoRuntimeHero
	var enemy := fixture.enemy as EchoRuntimeEnemy
	var action := load("res://data/heroes/echo/actions/pain_transfer.tres") as Action

	await action.effects[1].execute(echo, [enemy], manager, action)
	await action.effects[2].execute(echo, [echo], manager, action)
	await enemy._fire_condition_event(
		Trigger.TriggerType.ON_BEING_HIT, {"attacker": ally},
	)
	await enemy._fire_condition_event(
		Trigger.TriggerType.ON_BEING_HIT, {"attacker": ally},
	)

	assert_eq(echo.healing_events, [20, 20])
	assert_eq(ally.healing_events, [20, 20])
	assert_eq(defeated.healing_events, [])
	assert_eq(defeated.current_hp, 0)
	assert_true(defeated.is_defeated)
	assert_true(enemy.has_condition("Pain Transfer"))
	assert_true(echo.has_condition("Pain Transfer Removal"))

	await echo._fire_condition_event(Trigger.TriggerType.ON_TURN_START)

	assert_false(enemy.has_condition("Pain Transfer"))
	assert_false(echo.has_condition("Pain Transfer Removal"))
	_free_echo_runtime_fixture(fixture)


func test_production_suppress_cleanup_is_unique_and_runs_on_echo_shift() -> void:
	var fixture := _echo_runtime_fixture(false, true)
	var manager := fixture.manager as RecordingBattleManager
	var echo := fixture.echo as EchoRuntimeHero
	var enemy := fixture.enemy as EchoRuntimeEnemy
	var other_enemy := fixture.other_enemy as EchoRuntimeEnemy
	var suppress := load("res://data/heroes/echo/actions/force_field.tres") as Action
	if not assert_eq(suppress.effects.size(), 2, "Suppress has debuff and cleanup effects"):
		_free_echo_runtime_fixture(fixture)
		return

	for target: EchoRuntimeEnemy in [enemy, other_enemy]:
		await suppress.effects[0].execute(echo, [target], manager, suppress)
		await suppress.effects[1].execute(echo, [echo], manager, suppress)

	assert_true(enemy.has_condition("Suppress"))
	assert_true(other_enemy.has_condition("Suppress"))
	assert_eq(echo.active_conditions.filter(
		func(condition: Condition) -> bool:
			return condition.condition_name == "Suppress Cleanup"
	).size(), 1)

	await echo._fire_condition_event(Trigger.TriggerType.ON_SHIFT)

	assert_false(enemy.has_condition("Suppress"))
	assert_false(other_enemy.has_condition("Suppress"))
	assert_false(echo.has_condition("Suppress Cleanup"))
	_free_echo_runtime_fixture(fixture)


func test_production_inversion_destroys_four_guard_for_one_three_hundred_percent_hit() -> void:
	var fixture := _echo_runtime_fixture()
	var echo := fixture.echo as EchoRuntimeHero
	var enemy := fixture.enemy as EchoRuntimeEnemy
	var inversion := load("res://data/heroes/echo/actions/inversion.tres") as Action
	assert_eq(inversion.effects.size(), 1)
	if inversion.effects.size() != 1:
		_free_echo_runtime_fixture(fixture)
		return
	var effect := inversion.effects[0] as Effect_Damage_Inversion
	assert_not_null(effect)
	if effect == null:
		_free_echo_runtime_fixture(fixture)
		return
	enemy.current_guard = 6

	await effect.execute(echo, [enemy], fixture.manager, inversion)

	assert_eq(enemy.guard_changes, [-4])
	assert_eq(enemy.current_guard, 2)
	assert_eq(enemy.damage_results.size(), 1)
	var result := enemy.damage_results[0]
	assert_almost_eq(result.request.base_potency, 0.75, 0.0001)
	assert_almost_eq(result.request.potency, 3.0, 0.0001)
	assert_eq(result.request.base_power, echo.current_stats.psyche)
	assert_eq(result.request.damage_type, Action.DamageType.PIERCING)
	_free_echo_runtime_fixture(fixture)


func test_production_inversion_scales_single_hit_by_guard_actually_destroyed() -> void:
	var fixture := _echo_runtime_fixture()
	var echo := fixture.echo as EchoRuntimeHero
	var enemy := fixture.enemy as EchoRuntimeEnemy
	var inversion := load("res://data/heroes/echo/actions/inversion.tres") as Action
	if inversion.effects.size() != 1:
		assert_eq(inversion.effects.size(), 1)
		_free_echo_runtime_fixture(fixture)
		return
	var effect := inversion.effects[0] as Effect_Damage_Inversion
	if effect == null:
		assert_not_null(effect)
		_free_echo_runtime_fixture(fixture)
		return
	enemy.current_guard = 2

	await effect.execute(echo, [enemy], fixture.manager, inversion)

	assert_eq(enemy.guard_changes, [-2])
	assert_eq(enemy.current_guard, 0)
	assert_eq(enemy.damage_results.size(), 1)
	assert_almost_eq(enemy.damage_results[0].request.potency, 1.5, 0.0001)
	_free_echo_runtime_fixture(fixture)


func test_production_inversion_preview_scales_one_hit_by_target_guard() -> void:
	var fixture := _echo_runtime_fixture()
	var echo := fixture.echo as EchoRuntimeHero
	var enemy := fixture.enemy as EchoRuntimeEnemy
	var inversion := load("res://data/heroes/echo/actions/inversion.tres") as Action
	var effect := inversion.effects[0] as Effect_Damage_Inversion
	enemy.current_guard = 4

	var preview := DamagePreview.for_effect(
		effect,
		echo,
		enemy,
		inversion,
		1,
		false,
	)

	assert_almost_eq(preview.request.base_potency, 0.75, 0.0001)
	assert_almost_eq(preview.request.potency, 3.0, 0.0001)
	assert_eq(preview.request.damage_type, Action.DamageType.PIERCING)

	enemy.current_guard = 0
	var zero_guard_preview := DamagePreview.for_effect(
		effect,
		echo,
		enemy,
		inversion,
		1,
		false,
	)
	assert_almost_eq(zero_guard_preview.request.potency, 0.0, 0.0001)
	_free_echo_runtime_fixture(fixture)


func test_mind_storm_uses_focus_remaining_after_payment() -> void:
	var fixture := _echo_runtime_fixture()
	var echo := fixture.echo as EchoRuntimeHero
	var enemy := fixture.enemy as EchoRuntimeEnemy
	echo.current_focus = 10
	var action := load("res://data/heroes/echo/actions/mind_storm.tres") as Action
	var effect := action.effects[0] as Effect_Damage

	var result := DamagePreview.for_effect(effect, echo, enemy, action, 1, false)

	assert_almost_eq(result.request.base_potency, 5.0, 0.0001)
	assert_almost_eq(result.request.potency, 10.0, 0.0001)
	assert_eq(result.final_damage, 1000)
	assert_eq(echo.current_focus, 10)
	_free_echo_runtime_fixture(fixture)


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

	for target: BattleCombatant in [vulnerable, breached, normal]:
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
	var hero := CardSceneTestFixture.bind(
		self, RecordingHero.new(), BattleCombatant.Faction.HERO, null, manager,
	) as RecordingHero
	hero.current_stats = ActorStats.new()
	(hero.combatant as HeroCombatant).current_focus = 10
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
	var hero := CardSceneTestFixture.bind(
		self, FocusRefundHero.new(), BattleCombatant.Faction.HERO, null, manager,
	) as FocusRefundHero
	hero.current_stats = ActorStats.new()
	(hero.combatant as HeroCombatant).current_focus = 5
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
	var hero := CardSceneTestFixture.bind(
		self, RecordingHero.new(), BattleCombatant.Faction.HERO, null, manager,
	) as RecordingHero
	hero.current_stats = ActorStats.new()
	(hero.combatant as HeroCombatant).current_focus = 1
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
	var stats := ActorStats.new()
	stats.attack = base_power
	stats.psyche = base_power
	stats.overload = overload
	stats.max_hp = 1000
	actor.setup_base(stats, BattleCombatant.Faction.HERO)
	actor.current_hp = 1000
	actor.current_guard = guard
	return actor


func _application_fixture(hp: int, max_hp: int) -> ApplicationFixture:
	var battle_manager := ApplicationBattleManager.new()
	battle_manager.battle_speed = 1.0
	add_child_autofree(battle_manager)
	battle_manager.hero_area = Control.new()
	battle_manager.enemy_area = Control.new()
	battle_manager.add_child(battle_manager.hero_area)
	battle_manager.add_child(battle_manager.enemy_area)
	var target := _application_target(battle_manager, hp, max_hp)

	var attacker := HeroCardScene.instantiate() as ActorCard
	add_child_autofree(attacker)
	CardSceneTestFixture.bind(
		self, attacker, BattleCombatant.Faction.HERO, ActorStats.new(),
		battle_manager,
	)
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


func _application_target(
	manager: BattleManager,
	hp: int,
	max_hp: int,
) -> RecordingApplicationTarget:
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
	var stats := ActorStats.new()
	stats.max_hp = max_hp
	CardSceneTestFixture.bind(
		self, target, BattleCombatant.Faction.HERO, stats, manager,
	)
	target.current_stats.max_hp = max_hp
	target.current_hp = hp
	target.current_guard = 0
	target.update_health_bar()
	return target


func _applying_damage(damage_type: Action.DamageType) -> ApplyingDamageEffect:
	var effect := ApplyingDamageEffect.new()
	effect.damage_type = damage_type
	effect.potency = 1.0
	return effect


func _track_defeats(actor: ActorCard) -> IntCounter:
	var counter := IntCounter.new()
	actor.actor_defeated.connect(func(_defeated_actor: ActorCard) -> void:
		counter.value += 1
	)
	return counter


func _production_condition(path: String, attacker: ActorCard) -> Condition:
	var condition := (load(path) as Condition).duplicate(true) as Condition
	condition.attacker = attacker
	return condition


func _application_party_hero(
	manager: BattleManager,
	actor_name: String,
	attack: int,
	psyche: int,
	max_hp: int,
	hp: int,
	defeated: bool = false,
) -> HeroCard:
	var hero := HeroCardScene.instantiate() as HeroCard
	manager.hero_area.add_child(hero)
	CardSceneTestFixture.bind(
		self, hero, BattleCombatant.Faction.HERO, ActorStats.new(), manager,
	)
	_configure_application_actor(
		hero, actor_name, attack, psyche, max_hp, hp, defeated,
	)
	return hero


func _configure_application_actor(
	actor: ActorCard,
	actor_name: String,
	attack: int,
	psyche: int,
	max_hp: int,
	hp: int,
	defeated: bool = false,
) -> void:
	actor.actor_name = actor_name
	actor.current_stats = ActorStats.new()
	actor.current_stats.attack = attack
	actor.current_stats.psyche = psyche
	actor.current_stats.aim = 0
	actor.current_stats.max_hp = max_hp
	actor.current_hp = hp
	actor.current_guard = 0
	actor.is_defeated = defeated
	actor.update_health_bar()


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
		fixture.attacker.combatant,
		fixture.target.combatant,
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


func _echo_runtime_fixture(
	include_party: bool = false,
	include_second_enemy: bool = false,
) -> Dictionary:
	var manager := RecordingBattleManager.new()
	var hero_area := Control.new()
	var enemy_area := Control.new()
	manager.hero_area = hero_area
	manager.enemy_area = enemy_area
	manager.add_child(hero_area)
	manager.add_child(enemy_area)

	var echo := _echo_runtime_hero("Echo", 40, 1000, manager)
	var enemy := _echo_runtime_enemy("Target", 1000, manager)
	hero_area.add_child(echo)
	enemy_area.add_child(enemy)
	manager.actor_list = [echo, enemy]
	manager.current_actor = enemy
	echo.battle_manager = manager
	enemy.battle_manager = manager
	var fixture := {"manager": manager, "echo": echo, "enemy": enemy}
	if include_party:
		var ally := _echo_runtime_hero("Ally", 5, 100, manager)
		var defeated := _echo_runtime_hero("Defeated", 5, 100, manager)
		defeated.current_hp = 0
		defeated.is_defeated = true
		hero_area.add_child(ally)
		hero_area.add_child(defeated)
		ally.battle_manager = manager
		defeated.battle_manager = manager
		manager.actor_list.append_array([ally, defeated])
		fixture["ally"] = ally
		fixture["defeated"] = defeated
	if include_second_enemy:
		var other_enemy := _echo_runtime_enemy("Other Target", 1000, manager)
		enemy_area.add_child(other_enemy)
		other_enemy.battle_manager = manager
		manager.actor_list.append(other_enemy)
		fixture["other_enemy"] = other_enemy
	return fixture


func _echo_runtime_hero(
	actor_name: String,
	psyche: int,
	max_hp: int,
	manager: BattleManager,
) -> EchoRuntimeHero:
	var hero := EchoRuntimeHero.new()
	var stats := ActorStats.new()
	stats.actor_name = actor_name
	stats.attack = 100
	stats.psyche = psyche
	stats.aim = 0
	stats.max_hp = max_hp
	hero.setup_base(stats, BattleCombatant.Faction.HERO, manager)
	hero.current_hp = max_hp - 40
	return hero


func _echo_runtime_enemy(
	actor_name: String,
	max_hp: int,
	manager: BattleManager,
) -> EchoRuntimeEnemy:
	var enemy := EchoRuntimeEnemy.new()
	var stats := ActorStats.new()
	stats.actor_name = actor_name
	stats.max_hp = max_hp
	enemy.setup_base(stats, BattleCombatant.Faction.ENEMY, manager)
	return enemy


func _free_echo_runtime_fixture(fixture: Dictionary) -> void:
	(fixture.manager as BattleManager).free()


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
