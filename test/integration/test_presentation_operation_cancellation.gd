extends GutTest

const HeroCardScene := preload("res://src/battle/hero_card.tscn")


class SuspendedActingPresentation extends CombatantPresentation:
	signal release_acting

	func set_acting(active: bool):
		acting = active
		var operation := _begin_operation()
		release_acting.connect(operation.complete, CONNECT_ONE_SHOT)
		return operation


class SuspendedHealthPresentation extends CombatantPresentation:
	func sync_visual_health():
		var tween := create_tween()
		tween.tween_interval(60.0)
		return _operation_for_tween(tween)


class SuspendedActionPresentation extends CombatantPresentation:
	func hide_action():
		return _begin_operation()


class JoinablePresentation extends CombatantPresentation:
	func begin_child_operation() -> PresentationOperation:
		return _begin_operation()

	func operation_when_all(
		operations: Array[PresentationOperation],
	) -> PresentationOperation:
		return _operation_when_all(operations)


class OperationTrackingBattleManager extends BattleManager:
	var acting_resumed := false
	var acting_resume_presentation: CombatantPresentation
	var acting_resume_presentation_was_wired := false
	var acting_resume_target_invalidations := -1
	var health_resumed := false
	var hide_action_resumed := false
	var target_invalidation_count := 0

	func _ready() -> void:
		target_invalidated.connect(
			func(_combatant: BattleCombatant) -> void:
				target_invalidation_count += 1
		)

	func begin_acting(combatant: BattleCombatant) -> void:
		await _set_actor_acting(combatant, true)
		acting_resume_presentation = presentation_for(combatant) \
			if is_instance_valid(combatant) else null
		acting_resume_presentation_was_wired = \
			acting_resume_presentation != null \
			and acting_resume_presentation.target_pressed.is_connected(_on_target_pressed) \
			and _presentation_exit_callbacks.has(acting_resume_presentation)
		acting_resume_target_invalidations = target_invalidation_count
		acting_resumed = true

	func begin_health_flush() -> void:
		await _flush_all_health_animations()
		health_resumed = true

	func begin_hide_action(combatant: BattleCombatant) -> void:
		await _hide_action(combatant)
		hide_action_resumed = true


func test_operation_when_all_ignores_completed_children_and_waits_for_every_pending_child() -> void:
	var presentation := JoinablePresentation.new()
	add_child_autofree(presentation)
	var completed := PresentationOperation.already_completed()
	var first := presentation.begin_child_operation()
	var second := presentation.begin_child_operation()
	var operations: Array[PresentationOperation] = [completed, first, second]

	var joined := presentation.operation_when_all(operations)

	assert_false(joined.is_completed)
	first.complete()
	assert_false(joined.is_completed, "one pending child still owns the wait")
	second.complete()
	assert_true(joined.is_completed, "the last pending child completes the join")


func test_operation_when_all_is_completed_for_no_pending_children() -> void:
	var presentation := JoinablePresentation.new()
	add_child_autofree(presentation)
	var completed := PresentationOperation.already_completed()
	var operations: Array[PresentationOperation] = [null, completed]

	var joined := presentation.operation_when_all(operations)

	assert_true(joined.is_completed)


func test_completing_operation_when_all_does_not_complete_its_children() -> void:
	var presentation := JoinablePresentation.new()
	add_child_autofree(presentation)
	var first := presentation.begin_child_operation()
	var second := presentation.begin_child_operation()
	var operations: Array[PresentationOperation] = [first, second]
	var joined := presentation.operation_when_all(operations)

	joined.complete()

	assert_true(joined.is_completed)
	assert_false(first.is_completed, "a join never owns its first child")
	assert_false(second.is_completed, "a join never owns its second child")
	first.complete()
	second.complete()


func test_freeing_presentation_resumes_manager_acting_wait() -> void:
	var manager := OperationTrackingBattleManager.new()
	var hero := HeroCombatant.new()
	var presentation := SuspendedActingPresentation.new()
	manager.add_child(hero)
	manager.add_child(presentation)
	add_child_autofree(manager)
	presentation.bind(hero)
	manager.register_presentation(hero, presentation)

	manager.begin_acting(hero)
	await get_tree().process_frame
	assert_false(manager.acting_resumed, "manager is waiting for the visual transition")

	presentation.free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		manager.acting_resumed,
		"freeing the view completes its pending operation for manager orchestration",
	)
	assert_null(
		manager.acting_resume_presentation,
		"tree exit removes the registry entry before the continuation resumes",
	)
	assert_eq(manager.acting_resume_target_invalidations, 1)


func test_replacing_presentation_resumes_manager_acting_wait() -> void:
	var manager := OperationTrackingBattleManager.new()
	var hero := HeroCombatant.new()
	var presentation := SuspendedActingPresentation.new()
	var replacement := CombatantPresentation.new()
	manager.add_child(hero)
	manager.add_child(presentation)
	manager.add_child(replacement)
	add_child_autofree(manager)
	presentation.bind(hero)
	replacement.bind(hero)
	manager.register_presentation(hero, presentation)

	manager.begin_acting(hero)
	await get_tree().process_frame
	assert_false(manager.acting_resumed, "manager is waiting for the visual transition")

	manager.register_presentation(hero, replacement)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		manager.acting_resumed,
		"replacing the view completes its pending operation for manager orchestration",
	)
	assert_same(
		manager.acting_resume_presentation,
		replacement,
		"the resumed continuation can only observe the fully registered replacement",
	)
	assert_true(manager.acting_resume_presentation_was_wired)
	assert_eq(manager.acting_resume_target_invalidations, 0)


func test_unregistering_presentation_resumes_after_registry_removal() -> void:
	var manager := OperationTrackingBattleManager.new()
	var hero := HeroCombatant.new()
	var presentation := SuspendedActingPresentation.new()
	manager.add_child(hero)
	manager.add_child(presentation)
	add_child_autofree(manager)
	presentation.bind(hero)
	manager.register_presentation(hero, presentation)
	manager.begin_acting(hero)
	await get_tree().process_frame
	assert_false(manager.acting_resumed, "manager is waiting for the visual transition")

	manager.unregister_presentation(hero)

	assert_true(
		manager.acting_resumed,
		"unregistering completes the pending operation synchronously",
	)
	assert_null(
		manager.acting_resume_presentation,
		"the resumed continuation cannot observe the retired presentation",
	)
	assert_eq(manager.acting_resume_target_invalidations, 1)


func test_pruning_freed_combatant_resumes_after_registry_removal() -> void:
	var manager := OperationTrackingBattleManager.new()
	var hero := HeroCombatant.new()
	var presentation := SuspendedActingPresentation.new()
	manager.add_child(presentation)
	add_child_autofree(manager)
	presentation.bind(hero)
	manager.register_presentation(hero, presentation)
	manager.begin_acting(hero)
	await get_tree().process_frame
	assert_false(manager.acting_resumed, "manager is waiting for the visual transition")

	hero.free()
	manager._all_combatants_with_presentations()

	assert_true(manager.acting_resumed, "stale-registry pruning completes pending operations")
	assert_null(manager.acting_resume_presentation)


func test_freeing_presentation_resumes_manager_health_wait() -> void:
	var manager := OperationTrackingBattleManager.new()
	var hero := HeroCombatant.new()
	var presentation := SuspendedHealthPresentation.new()
	manager.add_child(hero)
	manager.add_child(presentation)
	add_child_autofree(manager)
	presentation.bind(hero)
	manager.register_presentation(hero, presentation)

	manager.begin_health_flush()
	await get_tree().process_frame
	assert_false(manager.health_resumed, "manager is waiting for visual health sync")

	presentation.free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		manager.health_resumed,
		"freeing the view completes its health operation for manager orchestration",
	)


func test_replacing_presentation_resumes_manager_health_wait() -> void:
	var manager := OperationTrackingBattleManager.new()
	var hero := HeroCombatant.new()
	var presentation := SuspendedHealthPresentation.new()
	var replacement := CombatantPresentation.new()
	manager.add_child(hero)
	manager.add_child(presentation)
	manager.add_child(replacement)
	add_child_autofree(manager)
	presentation.bind(hero)
	replacement.bind(hero)
	manager.register_presentation(hero, presentation)

	manager.begin_health_flush()
	await get_tree().process_frame
	assert_false(manager.health_resumed, "manager is waiting for visual health sync")

	manager.register_presentation(hero, replacement)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		manager.health_resumed,
		"replacing the view completes its health operation for manager orchestration",
	)


func test_repeated_card_health_sync_completes_replaced_health_operation() -> void:
	var manager := OperationTrackingBattleManager.new()
	manager.battle_speed = 0.1
	var hero := HeroCombatant.new()
	var stats := ActorStats.new()
	stats.max_hp = 100
	hero.setup_base(stats, BattleCombatant.Faction.HERO, manager)
	var card := HeroCardScene.instantiate() as HeroCard
	card.duration = 60.0
	card.battle_manager = manager
	manager.add_child(hero)
	manager.add_child(card)
	add_child_autofree(manager)
	await get_tree().process_frame
	assert_true(card.bind_combatant(hero))
	hero.current_hp = 50
	card.hp_bar_actual.value = 100.0
	card.hp_bar_ghost.value = 100.0
	assert_true(manager.register_presentation(hero, card.presentation))
	var acting_operation: PresentationOperation = card.presentation.set_acting(true)
	card.action_display.show()
	card.action_display.modulate.a = 1.0
	var hide_operation: PresentationOperation = card.presentation.hide_action()

	manager.begin_health_flush()
	await get_tree().process_frame
	assert_false(manager.health_resumed, "manager is waiting for the first health tween")

	var replacement_operation: PresentationOperation = \
		card.presentation.sync_visual_health()

	assert_true(
		manager.health_resumed,
		"replacing the health tween completes the manager's first operation",
	)
	assert_false(
		replacement_operation.is_completed,
		"the replacement health operation remains independently pending",
	)
	assert_false(acting_operation.is_completed, "health replacement preserves acting")
	assert_false(hide_operation.is_completed, "health replacement preserves action hide")
	card.presentation.cancel_pending_operations()


func test_freeing_presentation_resumes_manager_hide_action_wait() -> void:
	var manager := OperationTrackingBattleManager.new()
	var hero := HeroCombatant.new()
	var presentation := SuspendedActionPresentation.new()
	manager.add_child(hero)
	manager.add_child(presentation)
	add_child_autofree(manager)
	presentation.bind(hero)
	manager.register_presentation(hero, presentation)

	manager.begin_hide_action(hero)
	await get_tree().process_frame
	assert_false(
		manager.hide_action_resumed,
		"manager is waiting for the action-label transition",
	)

	presentation.free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		manager.hide_action_resumed,
		"freeing the view completes its hide operation for manager orchestration",
	)


func test_replacing_presentation_resumes_manager_hide_action_wait() -> void:
	var manager := OperationTrackingBattleManager.new()
	var hero := HeroCombatant.new()
	var presentation := SuspendedActionPresentation.new()
	var replacement := CombatantPresentation.new()
	manager.add_child(hero)
	manager.add_child(presentation)
	manager.add_child(replacement)
	add_child_autofree(manager)
	presentation.bind(hero)
	replacement.bind(hero)
	manager.register_presentation(hero, presentation)

	manager.begin_hide_action(hero)
	await get_tree().process_frame
	assert_false(
		manager.hide_action_resumed,
		"manager is waiting for the action-label transition",
	)

	manager.register_presentation(hero, replacement)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		manager.hide_action_resumed,
		"replacing the view completes its hide operation for manager orchestration",
	)


func test_card_acting_returns_pending_operation_for_slide_tween() -> void:
	var card := HeroCardScene.instantiate() as HeroCard
	card.duration = 60.0
	add_child_autofree(card)
	await get_tree().process_frame

	var operation: Variant = card.presentation.set_acting(true)

	assert_true(card.highlight_panel.visible, "acting highlight remains immediate")
	assert_true(operation is PresentationOperation)
	if operation is PresentationOperation:
		assert_false(operation.is_completed, "manager can wait for the card slide")
		card.presentation.cancel_pending_operations()


func test_card_hide_action_returns_pending_operation_for_fade_tween() -> void:
	var manager := OperationTrackingBattleManager.new()
	var card := HeroCardScene.instantiate() as HeroCard
	manager.battle_speed = 0.1
	card.battle_manager = manager
	add_child_autofree(manager)
	add_child_autofree(card)
	await get_tree().process_frame
	card.action_display.show()
	card.action_display.modulate.a = 1.0

	var operation: Variant = card.presentation.hide_action()

	assert_true(card.action_display.visible, "action label remains visible while fading")
	assert_true(operation is PresentationOperation)
	if operation is PresentationOperation:
		assert_false(operation.is_completed, "manager can wait for the action-label fade")
		card.presentation.cancel_pending_operations()
