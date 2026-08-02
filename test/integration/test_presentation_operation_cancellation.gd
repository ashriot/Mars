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


class OperationTrackingBattleManager extends BattleManager:
	var acting_resumed := false
	var health_resumed := false
	var hide_action_resumed := false

	func _ready() -> void:
		pass

	func begin_acting(combatant: BattleCombatant) -> void:
		await _set_actor_acting(combatant, true)
		acting_resumed = true

	func begin_health_flush() -> void:
		await _flush_all_health_animations()
		health_resumed = true

	func begin_hide_action(combatant: BattleCombatant) -> void:
		await _hide_action(combatant)
		hide_action_resumed = true


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
