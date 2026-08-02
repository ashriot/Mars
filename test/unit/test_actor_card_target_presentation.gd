extends GutTest

const HeroCardScene := preload("res://src/battle/hero_card.tscn")
const EnemyCardScene := preload("res://src/battle/enemy_card.tscn")


class LifecycleBattleManager extends BattleManager:
	signal wait_released
	signal effect_released

	var hold_wait := false
	var effect_started := false


	func wait(_duration: float = 0.01) -> void:
		if hold_wait:
			await wait_released


	func execute_triggered_effect(
		_actor: BattleCombatant,
		_effect: ActionEffect,
		_targets: Array[BattleCombatant],
		_action: Action,
		_context: Dictionary = {},
	) -> void:
		effect_started = true
		await effect_released


func _cards() -> Array[ActorCard]:
	var cards: Array[ActorCard] = []
	for scene: PackedScene in [HeroCardScene, EnemyCardScene]:
		var card := scene.instantiate() as ActorCard
		add_child_autofree(card)
		var model: BattleCombatant = HeroCombatant.new() \
			if card is HeroCard else EnemyCombatant.new()
		card.add_child(model)
		var stats := ActorStats.new()
		stats.actor_name = "Card"
		stats.max_hp = 100
		model.setup_base(
			stats,
			BattleCombatant.Faction.HERO if card is HeroCard \
			else BattleCombatant.Faction.ENEMY,
		)
		card.bind_combatant(model)
		cards.append(card)
	return cards


func _visible_focus_pips(hero: HeroCard) -> int:
	var visible_count := 0
	for pip: Control in hero.focus_bar.get_children():
		if pip.visible:
			visible_count += 1
	return visible_count


func _condition_for(event_type: Trigger.TriggerType, owner: BattleCombatant) -> Condition:
	var effect := ActionEffect.new()
	effect.target_type = Action.TargetType.SELF
	var trigger := Trigger.new()
	trigger.trigger_type = event_type
	trigger.effects_to_run = [effect]
	var condition := Condition.new()
	condition.condition_name = "Lifecycle boundary"
	condition.attacker = owner
	condition.triggers = [trigger]
	return condition


func test_hero_and_enemy_share_normal_available_and_selected_target_states() -> void:
	for card in _cards():
		var outline := card.get_node("Panel/TargetOutline") as Panel
		var pulse := card.get_node("Panel/TargetPulse") as Panel
		assert_eq(card.get_target_presentation(), ActorCard.TargetPresentation.NORMAL)
		assert_false(outline.visible)
		assert_false(pulse.visible)

		card.set_target_presentation(ActorCard.TargetPresentation.AVAILABLE)
		assert_true(outline.visible)
		assert_false(pulse.visible)
		var available_style := outline.get_theme_stylebox(&"panel") as StyleBoxFlat
		assert_eq(available_style.border_color, Color.WHITE)

		card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
		assert_true(outline.visible)
		assert_true(pulse.visible)
		assert_not_null(card._target_pulse_tween)

		card.set_target_presentation(ActorCard.TargetPresentation.NORMAL)
		assert_false(outline.visible)
		assert_false(pulse.visible)
		assert_null(card._target_pulse_tween)


func test_repeated_target_state_assignment_keeps_one_tween_and_exact_normal_cleanup() -> void:
	var card := _cards()[0]
	card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
	var first_tween := card._target_pulse_tween
	card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
	assert_same(card._target_pulse_tween, first_tween)
	card.set_target_presentation(ActorCard.TargetPresentation.AVAILABLE)
	assert_null(card._target_pulse_tween)
	assert_true(card.target_outline.visible)
	assert_false(card.target_pulse.visible)


func test_focus_bar_nonanimated_sync_matches_current_focus() -> void:
	var hero := _cards()[0] as HeroCard
	(hero.combatant as HeroCombatant).current_focus = 7

	hero.update_focus_bar(false)

	assert_eq(_visible_focus_pips(hero), 7)


func test_focus_refund_cancels_in_flight_pip_loss_animation() -> void:
	var hero := _cards()[0] as HeroCard
	(hero.combatant as HeroCombatant).current_focus = 7
	hero.update_focus_bar(false)
	var coordinate := load(
		"res://data/heroes/asher/conditions/coordinate.tres"
	) as Condition
	var model := hero.combatant as HeroCombatant
	model.active_conditions = [coordinate.duplicate(true)]

	await model.modify_focus(-5, {"paid_focus_cost": 5})

	await get_tree().create_timer(0.25).timeout

	assert_eq(model.current_focus, 7)
	assert_eq(_visible_focus_pips(hero), 7)
	assert_false(model.has_condition("Coordinate"))


func test_acting_outline_matches_queue_gold_and_stays_independent_of_targeting() -> void:
	for card in _cards():
		var acting_outline := card.get_node("Panel/Highlight") as Panel
		var acting_style := acting_outline.get_theme_stylebox(&"panel") as StyleBoxFlat
		if card is HeroCard:
			var definition := RoleDefinition.new()
			definition.color = Color(0.2, 0.65, 0.9, 1.0)
			var role := RoleData.new()
			role.source_definition = definition
			var hero := card as HeroCard
			var hero_model := hero.combatant as HeroCombatant
			hero_model.loaded_roles = [role]
			hero_model.current_role_index = 0
			hero.recolor()
		assert_eq(acting_style.border_color, CTBGauge.CURRENT_COLOR)
		assert_eq(acting_outline.modulate, Color.WHITE)
		assert_false(acting_outline.visible)

		card.highlight(true)
		card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
		assert_true(acting_outline.visible)
		assert_eq(acting_style.border_color, Color("ffc94a"))
		assert_eq(acting_outline.modulate, Color.WHITE)
		assert_true(card.target_outline.visible)
		assert_true(card.target_pulse.visible)

		card.highlight(false)
		assert_false(acting_outline.visible)
		assert_true(card.target_outline.visible)
		assert_true(card.target_pulse.visible)


func test_acting_outline_starts_before_turn_start_wait_completes() -> void:
	var card := _cards()[1]
	var manager := LifecycleBattleManager.new()
	manager.hold_wait = true
	card.battle_manager = manager
	card.combatant.battle_manager = manager

	card.presentation.set_acting(true)
	card.combatant.call_deferred(&"on_turn_started")
	await get_tree().process_frame

	assert_true(card.highlight_panel.visible)
	manager.wait_released.emit()
	await get_tree().process_frame
	assert_true(card.highlight_panel.visible)
	manager.free()


func test_acting_outline_ends_after_turn_end_triggers_complete() -> void:
	var card := _cards()[1]
	var manager := LifecycleBattleManager.new()
	card.battle_manager = manager
	card.combatant.battle_manager = manager
	card.combatant.active_conditions = [
		_condition_for(Trigger.TriggerType.ON_TURN_END, card.combatant),
	]
	card.presentation.set_acting(true)

	card.combatant.call_deferred(&"on_turn_ended")
	await get_tree().process_frame

	assert_true(manager.effect_started)
	assert_true(card.highlight_panel.visible)
	manager.effect_released.emit()
	await get_tree().process_frame
	await card.presentation.set_acting(false)
	assert_false(card.highlight_panel.visible)
	manager.free()


func test_selected_target_pulse_fades_from_transparent_to_at_most_half_opacity() -> void:
	var card := _cards()[0]
	card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
	assert_eq(card.target_pulse.modulate.a, 0.0)
	await get_tree().create_timer(0.4).timeout
	assert_lte(card.target_pulse.modulate.a, 0.5)
