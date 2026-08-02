extends GutTest

const HERO_CARD_SCENE := preload("res://src/battle/hero_card.tscn")
const ENEMY_CARD_SCENE := preload("res://src/battle/enemy_card.tscn")

var _saved_shake_intensity := 0.0


func before_each() -> void:
	_saved_shake_intensity = CombatPresentationSettings.shake_intensity
	CombatPresentationSettings.set_shake_intensity(1.0, false)
	TooltipManager.hide_tooltip()


func after_each() -> void:
	CombatPresentationSettings.set_shake_intensity(
		_saved_shake_intensity, false,
	)
	TooltipManager.hide_tooltip()
	for tween: Tween in get_tree().get_processed_tweens():
		tween.kill()


func test_hero_card_fixed_hover_owns_tooltip_and_target_signals_during_shake() -> void:
	await _assert_card_tooltip_boundary(HERO_CARD_SCENE)


func test_enemy_card_fixed_hover_owns_tooltip_and_target_signals_during_shake() -> void:
	await _assert_card_tooltip_boundary(ENEMY_CARD_SCENE)


func _assert_card_tooltip_boundary(scene: PackedScene) -> void:
	var card := scene.instantiate() as ActorCard
	card.position = Vector2(300, 300)
	card.size = Vector2(400, 180)
	add_child_autofree(card)
	await get_tree().process_frame
	card.rich_tooltip.bbcode_text = "Stable card statistics"
	var viewport := get_viewport()
	var outside := Vector2(20, 20)
	var inside := card.input_surface.get_global_rect().get_center()
	viewport.push_input(_mouse_motion_at(outside), true)
	await get_tree().process_frame
	watch_signals(card)

	viewport.push_input(_mouse_motion_at(inside), true)
	await get_tree().process_frame

	assert_same(viewport.gui_get_hovered_control(), card.input_surface)
	assert_gt(
		TooltipManager._timer.time_left, 0.0,
		"real fixed-surface hover registers the card tooltip",
	)
	assert_signal_emit_count(card, &"target_hovered", 1)
	await get_tree().create_timer(0.35).timeout
	assert_true(TooltipManager._tooltip_instance.visible)
	var outer_rect := card.get_global_rect()
	var input_rect := card.input_surface.get_global_rect()
	var visual_home := card.panel.global_position
	var tooltip_anchor := TooltipManager._tooltip_instance.position

	card.shake_panel(1.0)
	card.shake_tween.custom_step(0.025)
	await get_tree().process_frame

	assert_eq(card.get_global_rect(), outer_rect)
	assert_eq(card.input_surface.get_global_rect(), input_rect)
	assert_same(viewport.gui_get_hovered_control(), card.input_surface)
	assert_ne(card.panel.global_position, visual_home)
	assert_true(TooltipManager._tooltip_instance.visible)
	assert_eq(TooltipManager._tooltip_instance.position, tooltip_anchor)
	assert_signal_emit_count(card, &"target_hovered", 1)
	assert_signal_emit_count(card, &"target_unhovered", 0)

	viewport.push_input(_mouse_motion_at(outside), true)
	await get_tree().process_frame

	assert_false(TooltipManager._tooltip_instance.visible)
	assert_eq(TooltipManager._timer.time_left, 0.0)
	assert_signal_emit_count(card, &"target_hovered", 1)
	assert_signal_emit_count(card, &"target_unhovered", 1)


func _mouse_motion_at(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	return event
