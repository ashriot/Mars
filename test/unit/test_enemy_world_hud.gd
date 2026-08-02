extends GutTest


const HUD_SCENE := preload("res://src/battle/presentation/enemy_world_hud.tscn")
const WORLD_SCENE := preload("res://src/battle/presentation/battle_world_3d.tscn")

var _saved_input_mode: InputManager.InputMode
var _saved_presentation_mode: InputManager.PresentationMode
var _saved_consumed_mouse_button: MouseButton
var _saved_mouse_mode: Input.MouseMode


func before_each() -> void:
	_saved_input_mode = InputManager._active_mode
	_saved_presentation_mode = InputManager._presentation_mode
	_saved_consumed_mouse_button = InputManager._consumed_mouse_button
	_saved_mouse_mode = Input.mouse_mode


func after_each() -> void:
	InputManager._set_active_mode(_saved_input_mode)
	InputManager._set_presentation_mode(_saved_presentation_mode)
	InputManager._consumed_mouse_button = _saved_consumed_mouse_button
	Input.mouse_mode = _saved_mouse_mode


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


func test_intent_tooltip_is_reachable_without_blocking_real_target_input() -> void:
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	InputManager._consumed_mouse_button = MOUSE_BUTTON_NONE
	var hud := _hud()
	var enemy := _enemy_with_state(80, 3)
	var action := Action.new()
	action.action_name = "Incoming"
	action.description = "Incoming tooltip"
	action.effects = [ActionEffect.new()]
	action.target_type = Action.TargetType.SELF
	enemy.intended_action = action
	enemy.intended_targets = [enemy]
	hud.bind_combatant(enemy)
	hud.set_projected_head_position(Vector2(500, 300))
	await get_tree().process_frame
	watch_signals(hud)
	TooltipManager.hide_tooltip()
	assert_eq(TooltipManager._timer.time_left, 0.0)
	var intent_center := hud.intent_row.get_global_rect().get_center()

	get_viewport().push_input(_mouse_motion_at(Vector2(10, 600)), true)
	await get_tree().process_frame
	get_viewport().push_input(_mouse_motion_at(intent_center), true)
	await get_tree().process_frame

	assert_gt(TooltipManager._timer.time_left, 0.0)
	assert_signal_emitted(hud, &"hovered")
	get_viewport().push_input(_mouse_button_at(intent_center, true), true)
	await get_tree().process_frame
	assert_signal_emitted(hud, &"pressed")
	get_viewport().push_input(_mouse_button_at(intent_center, false), true)
	await get_tree().process_frame
	TooltipManager.hide_tooltip()


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


func test_controller_selected_details_flip_below_compact_at_safe_top() -> void:
	var fixture := _world_in_viewport(Vector2i(1280, 800))
	var world := fixture.world as BattleWorld3D
	var hud := HUD_SCENE.instantiate() as EnemyWorldHUD
	world.hud_layer.add_child(hud)
	hud.bind_combatant(_enemy_with_state(80, 3))
	hud.set_projected_head_position(Vector2(500, 114))
	hud.set_target_state(CombatantPresentation.TargetState.SELECTED)

	world._layout_enemy_huds()

	var safe_rect := Rect2(24, 24, 1232, 752)
	assert_true(hud.details.visible)
	assert_gt(hud.details.global_position.y, hud.compact_stack.global_position.y)
	assert_true(safe_rect.encloses(hud.get_visible_layout_rect()))


func test_hovered_details_stay_inside_safe_bottom_above_compact() -> void:
	var fixture := _world_in_viewport(Vector2i(1280, 800))
	var world := fixture.world as BattleWorld3D
	var hud := HUD_SCENE.instantiate() as EnemyWorldHUD
	world.hud_layer.add_child(hud)
	hud.bind_combatant(_enemy_with_state(80, 3))
	hud.set_projected_head_position(Vector2(500, 790))
	hud.target_region.mouse_entered.emit()

	world._layout_enemy_huds()

	var safe_rect := Rect2(24, 24, 1232, 752)
	assert_true(hud.details.visible)
	assert_lt(hud.details.global_position.y, hud.compact_stack.global_position.y)
	assert_true(safe_rect.encloses(hud.get_visible_layout_rect()))


func test_multiple_expanded_huds_resolve_without_visible_overlap() -> void:
	var fixture := _world_in_viewport(Vector2i(1280, 800))
	var world := fixture.world as BattleWorld3D
	var huds: Array[EnemyWorldHUD] = []
	for index in 5:
		var hud := HUD_SCENE.instantiate() as EnemyWorldHUD
		world.hud_layer.add_child(hud)
		hud.bind_combatant(_enemy_with_state(80 - index * 10, 3))
		hud.set_projected_head_position(Vector2(500, 300))
		hud.set_target_state(CombatantPresentation.TargetState.SELECTED)
		huds.append(hud)

	world._layout_enemy_huds()

	var safe_rect := Rect2(24, 24, 1232, 752)
	var compact_rects := _compact_rects(huds)
	var placed_details: Array[Rect2] = []
	for hud: EnemyWorldHUD in huds:
		var detail_rect := hud.details.get_global_rect()
		assert_true(safe_rect.encloses(detail_rect))
		for compact_rect: Rect2 in compact_rects:
			assert_false(detail_rect.intersects(compact_rect))
		for prior: Rect2 in placed_details:
			assert_false(detail_rect.intersects(prior))
		placed_details.append(detail_rect)


func test_details_visibility_never_reflows_resolved_compact_huds() -> void:
	var fixture := _world_in_viewport(Vector2i(1280, 800))
	var world := fixture.world as BattleWorld3D
	var huds: Array[EnemyWorldHUD] = []
	for index in 5:
		var hud := HUD_SCENE.instantiate() as EnemyWorldHUD
		world.hud_layer.add_child(hud)
		hud.bind_combatant(_enemy_with_state(80 - index * 10, 3))
		hud.set_projected_head_position(Vector2(500, 300))
		huds.append(hud)
	world._layout_enemy_huds()
	var compact_snapshot := _compact_rects(huds)

	huds[0].set_target_state(CombatantPresentation.TargetState.SELECTED)
	world._layout_enemy_huds()
	assert_eq(_compact_rects(huds), compact_snapshot)

	huds[1].target_region.mouse_entered.emit()
	huds[2].set_target_state(CombatantPresentation.TargetState.SELECTED)
	world._layout_enemy_huds()

	assert_eq(_compact_rects(huds), compact_snapshot)
	var safe_rect := Rect2(24, 24, 1232, 752)
	var placed_details: Array[Rect2] = []
	for hud: EnemyWorldHUD in huds:
		if not hud.details.visible:
			continue
		var detail_rect := hud.details.get_global_rect()
		assert_true(safe_rect.encloses(detail_rect))
		for compact_rect: Rect2 in compact_snapshot:
			assert_false(detail_rect.intersects(compact_rect))
		for prior: Rect2 in placed_details:
			assert_false(detail_rect.intersects(prior))
		placed_details.append(detail_rect)
	var detail_snapshot := placed_details.duplicate()

	world._layout_enemy_huds()

	assert_eq(_compact_rects(huds), compact_snapshot)
	assert_eq(_visible_detail_rects(huds), detail_snapshot)


func test_defeat_immediately_hides_disables_and_excludes_hud_from_layout() -> void:
	var world := WORLD_SCENE.instantiate() as BattleWorld3D
	add_child_autofree(world)
	var defeated_hud := HUD_SCENE.instantiate() as EnemyWorldHUD
	var survivor := HUD_SCENE.instantiate() as EnemyWorldHUD
	world.hud_layer.add_child(defeated_hud)
	world.hud_layer.add_child(survivor)
	var defeated_enemy := _enemy_with_state(60, 1)
	defeated_hud.bind_combatant(defeated_enemy)
	survivor.bind_combatant(_enemy_with_state(80, 3))
	defeated_hud.set_projected_head_position(Vector2(500, 300))
	survivor.set_projected_head_position(Vector2(500, 300))
	world._layout_enemy_huds()
	assert_eq(defeated_hud.compact_stack.global_position, Vector2(390, 210))
	assert_eq(survivor.compact_stack.global_position, Vector2(390, 126))
	watch_signals(defeated_hud)

	defeated_enemy.defeat()
	defeated_hud.set_projected_head_position(Vector2(500, 300))
	defeated_hud.target_region.mouse_entered.emit()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	defeated_hud.target_region.gui_input.emit(click)
	world._layout_enemy_huds()

	assert_false(defeated_hud.visible)
	assert_false(defeated_hud.has_valid_projection())
	assert_eq(defeated_hud.target_region.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_signal_not_emitted(defeated_hud, &"hovered")
	assert_signal_not_emitted(defeated_hud, &"pressed")
	assert_eq(survivor.compact_stack.global_position, Vector2(390, 210))


func test_presentation_owned_defeat_preserves_only_the_render_surface() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(60, 1)
	hud.enable_presentation_owned_defeat_fade()
	hud.bind_combatant(enemy)
	hud.set_projected_head_position(Vector2(500, 300))
	hud.set_projected_foot_position(Vector2(500, 500))
	watch_signals(hud)

	enemy.defeat()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud.target_region.mouse_entered.emit()
	hud.target_region.gui_input.emit(click)

	assert_true(hud.visible, "the owning presentation retains the fade surface")
	assert_false(hud.has_valid_projection())
	assert_eq(hud.target_region.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_signal_not_emitted(hud, &"hovered")
	assert_signal_not_emitted(hud, &"pressed")
	hud.complete_presentation_owned_defeat_fade()
	assert_false(hud.visible)


func test_model_tree_exit_invalidates_and_unbinds_surviving_hud() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(80, 3)
	hud.bind_combatant(enemy)
	hud.set_projected_head_position(Vector2(500, 300))
	watch_signals(hud)

	enemy.free()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud.target_region.gui_input.emit(click)

	assert_null(hud.combatant)
	assert_false(hud.visible)
	assert_false(hud.has_valid_projection())
	assert_eq(hud.target_region.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_signal_not_emitted(hud, &"pressed")


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


func _world_in_viewport(size: Vector2i) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var world := WORLD_SCENE.instantiate() as BattleWorld3D
	viewport.add_child(world)
	return {"viewport": viewport, "world": world}


func _compact_rects(huds: Array[EnemyWorldHUD]) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for hud: EnemyWorldHUD in huds:
		result.append(Rect2(hud.compact_stack.global_position, hud.COMPACT_SIZE))
	return result


func _visible_detail_rects(huds: Array[EnemyWorldHUD]) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for hud: EnemyWorldHUD in huds:
		if hud.details.visible:
			result.append(hud.details.get_global_rect())
	return result


func _mouse_motion_at(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	return event


func _mouse_button_at(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event
