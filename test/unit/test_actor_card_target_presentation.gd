extends GutTest

const HeroCardScene := preload("res://src/battle/hero_card.tscn")
const EnemyCardScene := preload("res://src/battle/enemy_card.tscn")


func _cards() -> Array[ActorCard]:
	var cards: Array[ActorCard] = []
	for scene: PackedScene in [HeroCardScene, EnemyCardScene]:
		var card := scene.instantiate() as ActorCard
		add_child_autofree(card)
		cards.append(card)
	return cards


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


func test_acting_outline_matches_queue_gold_and_stays_independent_of_targeting() -> void:
	for card in _cards():
		var acting_outline := card.get_node("Panel/Highlight") as Panel
		var acting_style := acting_outline.get_theme_stylebox(&"panel") as StyleBoxFlat
		assert_eq(acting_style.border_color, CTBGauge.CURRENT_COLOR)
		assert_false(acting_outline.visible)

		card.highlight(true)
		card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
		assert_true(acting_outline.visible)
		assert_eq(acting_style.border_color, Color("ffc94a"))
		assert_true(card.target_outline.visible)
		assert_true(card.target_pulse.visible)

		card.highlight(false)
		assert_false(acting_outline.visible)
		assert_true(card.target_outline.visible)
		assert_true(card.target_pulse.visible)


func test_selected_target_pulse_fades_from_transparent_to_at_most_half_opacity() -> void:
	var card := _cards()[0]
	card.set_target_presentation(ActorCard.TargetPresentation.SELECTED)
	assert_eq(card.target_pulse.modulate.a, 0.0)
	await get_tree().create_timer(0.4).timeout
	assert_lte(card.target_pulse.modulate.a, 0.5)
