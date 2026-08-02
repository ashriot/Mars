extends GutTest


const HUD_SCENE := preload("res://src/battle/presentation/enemy_world_hud.tscn")
const WORLD_SCENE := preload("res://src/battle/presentation/battle_world_3d.tscn")


func _hud() -> EnemyWorldHUD:
	var hud := HUD_SCENE.instantiate() as EnemyWorldHUD
	add_child_autofree(hud)
	return hud


func test_compact_stack_orders_intent_guard_hp_and_conditions() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(80, 3)

	assert_true(hud.bind_combatant(enemy))
	assert_true(hud.intent_row.get_index() < hud.vitals_row.get_index())
	assert_true(hud.vitals_row.get_index() < hud.conditions_row.get_index())
	assert_eq(hud.guard_value.text, "3")
	assert_eq(hud.hp_bar.value, 80.0)


func test_details_reveal_does_not_reflow_compact_stack() -> void:
	var hud := _hud()
	hud.bind_combatant(_enemy_with_state(80, 3))
	var compact_position := hud.compact_stack.position

	hud.set_details_visible(true)

	assert_true(hud.details.visible)
	assert_eq(hud.compact_stack.position, compact_position)


func test_rebinding_is_rejected_and_teardown_disconnects_model() -> void:
	var hud := _hud()
	var first := _enemy_with_state(80, 3)
	var second := _enemy_with_state(50, 0)
	assert_true(hud.bind_combatant(first))

	assert_false(hud.bind_combatant(second))
	assert_push_error("EnemyWorldHUD cannot be rebound to another combatant.")
	hud.free()
	first.hp_changed.emit(first, 10, 100)


func test_bound_model_signals_refresh_vitals_intent_and_conditions() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(80, 3)
	assert_true(hud.bind_combatant(enemy))

	enemy.current_hp = 45
	enemy.hp_changed.emit(enemy, 45, 100)
	enemy.current_guard = 1
	enemy.guard_changed.emit(enemy, 1)
	var condition := Condition.new()
	condition.condition_name = "Marked"
	condition.description = "Takes additional damage."
	condition.icon = GradientTexture1D.new()
	enemy.active_conditions = [condition]
	enemy.conditions_changed.emit(enemy)
	var action := Action.new()
	action.action_name = "Repair"
	action.effects = [ActionEffect.new()]
	action.target_type = Action.TargetType.SELF
	enemy.intended_action = action
	enemy.intended_targets = [enemy]
	enemy.presentation_event.emit(enemy, &"intent_changed", {})

	assert_eq(hud.hp_bar.value, 45.0)
	assert_eq(hud.guard_value.text, "1")
	assert_eq(hud.conditions_row.get_child_count(), 1)
	assert_same((hud.conditions_row.get_child(0) as TextureRect).texture, condition.icon)
	assert_eq(hud.intent_row.text, "Repair")


func test_target_state_and_hover_share_details_reveal() -> void:
	var hud := _hud()
	hud.bind_combatant(_enemy_with_state(80, 3))

	hud.set_target_state(CombatantPresentation.TargetState.SELECTED)
	assert_true(hud.details.visible)
	hud.set_target_state(CombatantPresentation.TargetState.NORMAL)
	assert_false(hud.details.visible)
	hud.target_region.mouse_entered.emit()
	assert_true(hud.details.visible)
	hud.target_region.mouse_exited.emit()
	assert_false(hud.details.visible)


func test_target_region_forwards_hover_and_press_signals() -> void:
	var hud := _hud()
	hud.bind_combatant(_enemy_with_state(80, 3))
	watch_signals(hud)

	hud.target_region.mouse_entered.emit()
	hud.target_region.mouse_exited.emit()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud.target_region.gui_input.emit(click)

	assert_signal_emitted(hud, &"hovered")
	assert_signal_emitted(hud, &"unhovered")
	assert_signal_emitted(hud, &"pressed")


func test_projected_head_positions_compact_rect_above_anchor() -> void:
	var hud := _hud()
	hud.bind_combatant(_enemy_with_state(80, 3))
	hud.set_projected_head_position(Vector2(500, 300))

	var desired := hud.get_desired_compact_rect()

	assert_eq(desired.get_center().x, 500.0)
	assert_eq(desired.end.y, 288.0)
	hud.apply_resolved_compact_rect(desired)
	assert_eq(hud.compact_stack.global_position, desired.position)


func test_projected_head_and_foot_size_padded_model_target_region() -> void:
	var hud := _hud()
	hud.bind_combatant(_enemy_with_state(80, 3))

	hud.set_projected_head_position(Vector2(500, 300))
	hud.set_projected_foot_position(Vector2(500, 500))

	assert_eq(hud.get_target_rect(), Rect2(452, 282, 96, 236))


func test_world_layout_resolves_visible_huds_in_spawn_order() -> void:
	var world := WORLD_SCENE.instantiate() as BattleWorld3D
	add_child_autofree(world)
	var first := HUD_SCENE.instantiate() as EnemyWorldHUD
	var second := HUD_SCENE.instantiate() as EnemyWorldHUD
	world.hud_layer.add_child(first)
	world.hud_layer.add_child(second)
	first.bind_combatant(_enemy_with_state(80, 3))
	second.bind_combatant(_enemy_with_state(60, 1))
	first.set_projected_head_position(Vector2(500, 300))
	second.set_projected_head_position(Vector2(500, 300))

	world._layout_enemy_huds()

	assert_eq(first.compact_stack.global_position, Vector2(390, 210))
	assert_eq(second.compact_stack.global_position, Vector2(390, 126))
	second.set_projection_visible(false)
	world._layout_enemy_huds()
	assert_eq(first.compact_stack.global_position, Vector2(390, 210))


func _enemy_with_state(hp: int, guard: int) -> EnemyCombatant:
	var enemy := EnemyCombatant.new()
	add_child_autofree(enemy)
	var stats := ActorStats.new()
	stats.actor_name = "Eye Drone"
	stats.max_hp = 100
	stats.kinetic_defense = 20
	stats.energy_defense = 35
	enemy.setup_base(stats, BattleCombatant.Faction.ENEMY)
	enemy.current_hp = hp
	enemy.current_guard = guard
	return enemy
