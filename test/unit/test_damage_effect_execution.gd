extends GutTest


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


class RecordingActor extends ActorCard:
	var breach_calls := 0
	var guard_changes: Array[int] = []
	var focus_changes: Array[int] = []
	var event_log: Array[String] = []

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
		_damage: int,
		_damage_effect: Effect_Damage,
		_attacker: ActorCard,
		_damage_type: Action.DamageType,
		_is_crit: bool,
	) -> void:
		return

	func take_healing(_heal_amount: int, _is_revive: bool = false) -> void:
		return

	func _fire_condition_event(
		event_type: Trigger.TriggerType,
		_context: Dictionary = {},
	) -> void:
		if event_type == Trigger.TriggerType.AFTER_BEING_ATTACKED:
			event_log.append("after")


class RecordingHero extends HeroCard:
	var focus_changes: Array[int] = []

	func modify_focus(amount: int) -> void:
		focus_changes.append(amount)
		current_focus = clampi(current_focus + amount, 0, 10)


class RecordingActionEffect extends ActionEffect:
	var received_contexts: Array[Dictionary] = []

	func execute(
		_attacker: ActorCard,
		_parent_targets: Array,
		_battle_manager: BattleManager,
		_action: Action = null,
		context: Dictionary = {},
	) -> void:
		received_contexts.append(context.duplicate(true))


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

	func _roll_percent(chance: int) -> bool:
		rolled_chances.append(chance)
		return roll_value <= chance

	func _pick_random_target(candidates: Array) -> ActorCard:
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
	) -> void:
		results.append(result)
		if defeat_first_target_after_hit and target == first_target:
			target.is_defeated = true
		if clear_attacker_guard_after_first_hit and results.size() == 1:
			attacker.current_guard = 0


func test_energy_causes_breach_before_damage_and_same_hit_gets_ovr() -> void:
	var outcome := await _execute_recorded_hit(
		Action.DamageType.ENERGY, 0, false, Action.DamageType.NONE,
		100, 75, 0, 100,
	)
	assert_eq(outcome.breach_calls, 1)
	assert_true(outcome.breached_when_request_built)
	assert_eq(outcome.result.request.overload_power, 75)
	assert_eq(outcome.result.effective_power, 175)


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

	await effect.execute(attacker, [target], manager)

	assert_eq(effect.results.size(), 1)
	assert_eq(event_log, ["wait", "after"])
	_free_recorded_nodes(manager, [attacker, target])


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
	assert_eq(hero.current_focus, 8)
	assert_eq(capture_effect.received_contexts.size(), 1)
	assert_eq(capture_effect.received_contexts[0].paid_focus_cost, 2)
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


func _recording_action_manager() -> RecordingBattleManager:
	var manager := RecordingBattleManager.new()
	manager.hero_area = Control.new()
	manager.enemy_area = Control.new()
	manager.current_action_panel = PanelContainer.new()
	manager.add_child(manager.hero_area)
	manager.add_child(manager.enemy_area)
	manager.add_child(manager.current_action_panel)
	return manager


func _free_recorded_nodes(manager: BattleManager, actors: Array) -> void:
	manager.free()
	for actor in actors:
		actor.free()
