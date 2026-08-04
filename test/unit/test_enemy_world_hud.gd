extends GutTest


const HUD_SCENE := preload("res://src/battle/presentation/enemy_world_hud.tscn")
const WORLD_SCENE := preload("res://src/battle/presentation/battle_world_3d.tscn")
const BOLD_FONT_PATH := "res://data/theme/fonts/suse_mono_bold.tres"
const COMPACT_WIDTH := 220.0
const HP_WIDTH := 168.0
const HP_GUARD_OVERLAP := 4.0
const GUARD_CONDITIONS_GAP := 5.0
const DETAILS_GAP := 4.0

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


func test_compact_stack_authors_layered_hp_and_overlapping_guard() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(80, 3)

	assert_true(hud.bind_combatant(enemy))
	await get_tree().process_frame
	assert_eq(hud.compact_stack.size.x, COMPACT_WIDTH)
	assert_eq(hud.intent_row.size.x, COMPACT_WIDTH)
	var hp_region: Control = hud.hp_region
	var feedback: ProgressBar = hud.hp_bar_feedback
	var actual: ProgressBar = hud.hp_bar_actual
	var guard_stack := hud.get_node_or_null("%GuardStack") as EnemyGuardStack
	assert_not_null(hp_region)
	assert_not_null(feedback)
	assert_not_null(actual)
	assert_not_null(guard_stack)
	if hp_region == null or feedback == null or actual == null or guard_stack == null:
		return
	assert_eq(hp_region.position, Vector2(26.0, 0.0))
	assert_eq(hp_region.size, Vector2(HP_WIDTH, 18.0))
	assert_eq(hp_region.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(feedback.get_rect(), Rect2(Vector2.ZERO, hp_region.size))
	assert_eq(actual.get_rect(), Rect2(Vector2.ZERO, hp_region.size))
	assert_eq(feedback.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(actual.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(feedback.show_percentage)
	assert_false(actual.show_percentage)
	_assert_rounded_style(feedback.get_theme_stylebox(&"background"))
	_assert_rounded_style(feedback.get_theme_stylebox(&"fill"))
	assert_true(actual.get_theme_stylebox(&"background") is StyleBoxEmpty)
	_assert_rounded_style(actual.get_theme_stylebox(&"fill"))
	assert_gt(actual.z_index, feedback.z_index)
	assert_eq(guard_stack.position, Vector2(9.0, 14.0))
	assert_eq(guard_stack.size.x, 202.0)
	assert_gt(guard_stack.position.y, hp_region.position.y)
	assert_eq(hp_region.position.y + hp_region.size.y - guard_stack.position.y, HP_GUARD_OVERLAP)
	assert_eq(guard_stack.guard_value.text, "3")
	assert_eq(feedback.value, 80.0)
	assert_eq(actual.value, 80.0)
	assert_eq(hp_region.tooltip_text, "80 / 100 HP")


func test_guard_depth_moves_conditions_and_details_only_five_pixels_per_layer() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(80, 0)
	hud.bind_combatant(enemy)
	await get_tree().process_frame
	var guard_stack := hud.get_node_or_null("%GuardStack") as EnemyGuardStack
	assert_not_null(guard_stack)
	if guard_stack == null:
		return
	var condition_positions: Array[float] = []
	var detail_positions: Array[float] = []
	var compact_heights: Array[float] = []
	for guard in [0, 7, 13, 23]:
		enemy.current_guard = guard
		enemy.guard_changed.emit(enemy, guard)
		await get_tree().process_frame
		var compact_rect := hud.get_desired_compact_rect()
		assert_eq(compact_rect.size.x, COMPACT_WIDTH)
		assert_eq(compact_rect.size.y, hud.compact_stack.size.y)
		assert_eq(
			hud.conditions_row.position.y,
			guard_stack.position.y + guard_stack.size.y + GUARD_CONDITIONS_GAP,
		)
		assert_eq(hud.details.position.y, hud.compact_stack.size.y + DETAILS_GAP)
		condition_positions.append(hud.conditions_row.position.y)
		detail_positions.append(hud.details.position.y)
		compact_heights.append(compact_rect.size.y)
	assert_eq(condition_positions[0], condition_positions[1])
	assert_eq(condition_positions[2] - condition_positions[1], 5.0)
	assert_eq(condition_positions[3] - condition_positions[2], 5.0)
	assert_eq(detail_positions[0], detail_positions[1])
	assert_eq(detail_positions[2] - detail_positions[1], 5.0)
	assert_eq(detail_positions[3] - detail_positions[2], 5.0)
	assert_eq(compact_heights[0], compact_heights[1])
	assert_eq(compact_heights[2] - compact_heights[1], 5.0)
	assert_eq(compact_heights[3] - compact_heights[2], 5.0)


func test_binding_and_guard_state_signals_render_vulnerable_then_breached() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(80, 0)
	enemy.is_in_danger = true
	hud.bind_combatant(enemy)
	var guard_stack := hud.get_node_or_null("%GuardStack") as EnemyGuardStack
	assert_not_null(guard_stack)
	if guard_stack == null:
		return
	assert_true(guard_stack.status_label.visible)
	assert_eq(guard_stack.status_label.text, "VULNERABLE")

	enemy.is_in_danger = false
	enemy.danger_changed.emit(enemy, false)
	assert_false(guard_stack.status_label.visible)
	enemy.is_breached = true
	enemy.breached.emit(enemy)
	assert_true(guard_stack.status_label.visible)
	assert_eq(guard_stack.status_label.text, "BREACHED")


func test_guard_value_stays_inside_current_shield_through_hud_component() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(80, 13)
	hud.bind_combatant(enemy)
	var guard_stack := hud.get_node_or_null("%GuardStack") as EnemyGuardStack
	assert_not_null(guard_stack)
	if guard_stack == null:
		return
	var current_shield := guard_stack.layers[1].get_child(2) as TextureRect
	assert_eq(guard_stack.guard_value.text, "13")
	assert_eq(
		guard_stack.guard_value.position,
		guard_stack.layers[1].position + current_shield.position,
	)


func test_full_guard_visual_extent_stays_inside_the_compact_hud_rect() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(80, 30)
	hud.bind_combatant(enemy)
	await get_tree().process_frame
	var compact_rect := hud.compact_stack.get_global_rect()

	_assert_guard_visuals_inside(hud.guard_stack, compact_rect)


func test_hud_keeps_existing_bold_font_resource_and_reports_hover_state() -> void:
	var hud := _hud()
	hud.bind_combatant(_enemy_with_state(80, 3))
	var guard_stack := hud.get_node_or_null("%GuardStack") as EnemyGuardStack
	assert_not_null(guard_stack)
	assert_eq(hud.intent_row.get_theme_font(&"normal_font").resource_path, BOLD_FONT_PATH)
	if guard_stack != null:
		assert_eq(guard_stack.guard_value.get_theme_font(&"font").resource_path, BOLD_FONT_PATH)
	assert_true(hud.has_method(&"is_hovered"))
	if not hud.has_method(&"is_hovered"):
		return
	assert_false(hud.call(&"is_hovered"))
	hud.target_region.mouse_entered.emit()
	assert_true(hud.call(&"is_hovered"))
	hud.target_region.mouse_exited.emit()
	assert_false(hud.call(&"is_hovered"))


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

	assert_eq(hud.hp_bar_feedback.max_value, 100.0)
	assert_eq(hud.hp_bar_actual.max_value, 100.0)
	assert_eq(hud.hp_region.tooltip_text, "45 / 100 HP")
	assert_eq(hud.guard_stack.guard_value.text, "1")
	assert_eq(hud.conditions_row.get_child_count(), 1)
	assert_same((hud.conditions_row.get_child(0) as TextureRect).texture, condition.icon)
	assert_eq(hud.intent_row.text, "Repair")


func test_damage_stages_yellow_feedback_until_the_hud_health_tween_settles() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(100, 3)
	assert_true(hud.bind_combatant(enemy))
	assert_true(hud.has_method(&"sync_visual_health"))
	if not hud.has_method(&"sync_visual_health"):
		return

	enemy.current_hp = 60
	enemy.hp_changed.emit(enemy, 60, 100)
	enemy.presentation_event.emit(enemy, &"damage_received", {})

	assert_eq(hud.hp_bar_actual.value, 60.0)
	assert_eq(hud.hp_bar_feedback.value, 100.0)
	assert_eq(_fill_color(hud.hp_bar_feedback), HealthFeedbackPalette.DAMAGE_YELLOW)
	var tween := hud.call(&"sync_visual_health") as Tween
	assert_not_null(tween)
	await get_tree().create_timer(0.55).timeout
	assert_eq(hud.hp_bar_actual.value, 60.0)
	assert_eq(hud.hp_bar_feedback.value, 60.0)


func test_healing_stages_green_feedback_until_the_hud_health_tween_settles() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(40, 3)
	assert_true(hud.bind_combatant(enemy))
	assert_true(hud.has_method(&"sync_visual_health"))
	if not hud.has_method(&"sync_visual_health"):
		return

	enemy.current_hp = 60
	enemy.hp_changed.emit(enemy, 60, 100)
	enemy.presentation_event.emit(enemy, &"healing_received", {})

	assert_eq(hud.hp_bar_actual.value, 40.0)
	assert_eq(hud.hp_bar_feedback.value, 60.0)
	assert_eq(_fill_color(hud.hp_bar_feedback), HealthFeedbackPalette.HEALING_GREEN)
	var tween := hud.call(&"sync_visual_health") as Tween
	assert_not_null(tween)
	await get_tree().create_timer(0.55).timeout
	assert_eq(hud.hp_bar_actual.value, 60.0)
	assert_eq(hud.hp_bar_feedback.value, 60.0)


func test_new_health_event_replaces_a_running_tween_from_the_displayed_value() -> void:
	var hud := _hud()
	var enemy := _enemy_with_state(100, 3)
	assert_true(hud.bind_combatant(enemy))
	assert_true(hud.has_method(&"sync_visual_health"))
	if not hud.has_method(&"sync_visual_health"):
		return

	enemy.current_hp = 60
	enemy.hp_changed.emit(enemy, 60, 100)
	enemy.presentation_event.emit(enemy, &"damage_received", {})
	var first_tween := hud.call(&"sync_visual_health") as Tween
	assert_not_null(first_tween)
	await get_tree().create_timer(0.2).timeout
	var displayed_feedback: float = hud.hp_bar_feedback.value
	assert_between(displayed_feedback, 60.0, 100.0)

	enemy.current_hp = 40
	enemy.hp_changed.emit(enemy, 40, 100)
	enemy.presentation_event.emit(enemy, &"damage_received", {})
	var replacement_tween := hud.call(&"sync_visual_health") as Tween
	assert_not_null(replacement_tween)
	assert_ne(replacement_tween, first_tween)
	await get_tree().process_frame
	assert_lt(hud.hp_bar_feedback.value, displayed_feedback)
	assert_gt(hud.hp_bar_feedback.value, 40.0)
	await get_tree().create_timer(0.55).timeout
	assert_eq(hud.hp_bar_actual.value, 40.0)
	assert_eq(hud.hp_bar_feedback.value, 40.0)


func test_target_state_does_not_reveal_details_but_pointer_hover_does() -> void:
	var hud := _hud()
	hud.bind_combatant(_enemy_with_state(80, 3))

	hud.set_target_state(CombatantPresentation.TargetState.SELECTED)
	assert_false(hud.details.visible)
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


func test_hp_region_passes_real_pointer_hover_and_press_to_target_region() -> void:
	InputManager._set_active_mode(InputManager.InputMode.KEYBOARD_MOUSE)
	InputManager._set_presentation_mode(InputManager.PresentationMode.POINTER)
	InputManager._consumed_mouse_button = MOUSE_BUTTON_NONE
	var hud := _hud()
	hud.bind_combatant(_enemy_with_state(80, 3))
	hud.set_projected_head_position(Vector2(500, 300))
	await get_tree().process_frame
	watch_signals(hud)
	var hp_center: Vector2 = hud.hp_region.get_global_rect().get_center()

	get_viewport().push_input(_mouse_motion_at(Vector2(10, 600)), true)
	await get_tree().process_frame
	get_viewport().push_input(_mouse_motion_at(hp_center), true)
	await get_tree().process_frame
	get_viewport().push_input(_mouse_button_at(hp_center, true), true)
	await get_tree().process_frame

	assert_eq(hud.hp_region.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(hud.hp_bar_feedback.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(hud.hp_bar_actual.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_true(hud.is_hovered())
	assert_signal_emitted(hud, &"hovered")
	assert_signal_emitted(hud, &"pressed")
	get_viewport().push_input(_mouse_button_at(hp_center, false), true)
	await get_tree().process_frame


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


func test_world_layout_keeps_close_huds_centered_on_their_own_heads() -> void:
	var world := WORLD_SCENE.instantiate() as BattleWorld3D
	add_child_autofree(world)
	var first := HUD_SCENE.instantiate() as EnemyWorldHUD
	var second := HUD_SCENE.instantiate() as EnemyWorldHUD
	world.hud_layer.add_child(first)
	world.hud_layer.add_child(second)
	first.bind_combatant(_enemy_with_state(80, 3))
	second.bind_combatant(_enemy_with_state(60, 1))
	first.set_projected_head_position(Vector2(500, 300))
	second.set_projected_head_position(Vector2(530, 300))

	world._layout_enemy_huds()

	assert_eq(first.compact_stack.global_position, Vector2(390, 201))
	assert_eq(second.compact_stack.global_position, Vector2(420, 201))
	assert_eq(first.compact_stack.global_position.y, second.compact_stack.global_position.y)
	assert_eq(first.compact_stack.get_global_rect().get_center().x, 500.0)
	assert_eq(second.compact_stack.get_global_rect().get_center().x, 530.0)
	second.set_projection_visible(false)
	world._layout_enemy_huds()
	assert_eq(first.compact_stack.global_position, Vector2(390, 201))


func test_world_layout_clamps_each_hud_independently_to_safe_edges() -> void:
	var fixture := _world_in_viewport(Vector2i(1280, 800))
	var world := fixture.world as BattleWorld3D
	var top_left := HUD_SCENE.instantiate() as EnemyWorldHUD
	var bottom_right := HUD_SCENE.instantiate() as EnemyWorldHUD
	world.hud_layer.add_child(top_left)
	world.hud_layer.add_child(bottom_right)
	top_left.bind_combatant(_enemy_with_state(80, 3))
	bottom_right.bind_combatant(_enemy_with_state(60, 1))
	top_left.set_projected_head_position(Vector2(0, 0))
	bottom_right.set_projected_head_position(Vector2(1280, 800))

	world._layout_enemy_huds()

	assert_eq(top_left.compact_stack.global_position, Vector2(24, 24))
	assert_eq(bottom_right.compact_stack.global_position, Vector2(1036, 689))


func test_world_layout_keeps_full_guard_visuals_inside_both_horizontal_safe_edges() -> void:
	var fixture := _world_in_viewport(Vector2i(1280, 800))
	var world := fixture.world as BattleWorld3D
	var left_hud := HUD_SCENE.instantiate() as EnemyWorldHUD
	var right_hud := HUD_SCENE.instantiate() as EnemyWorldHUD
	world.hud_layer.add_child(left_hud)
	world.hud_layer.add_child(right_hud)
	left_hud.bind_combatant(_enemy_with_state(80, 30))
	right_hud.bind_combatant(_enemy_with_state(60, 30))
	left_hud.set_projected_head_position(Vector2(0, 400))
	right_hud.set_projected_head_position(Vector2(1280, 400))
	await get_tree().process_frame

	world._layout_enemy_huds()
	var safe_rect := Rect2(Vector2(24, 24), Vector2(1232, 752))

	assert_eq(left_hud.compact_stack.global_position.x, safe_rect.position.x)
	assert_eq(right_hud.compact_stack.get_global_rect().end.x, safe_rect.end.x)
	_assert_guard_visuals_inside(left_hud.guard_stack, safe_rect)
	_assert_guard_visuals_inside(right_hud.guard_stack, safe_rect)


func test_visible_details_stay_four_pixels_below_their_own_compact_stack() -> void:
	var fixture := _world_in_viewport(Vector2i(1280, 800))
	var world := fixture.world as BattleWorld3D
	var huds: Array[EnemyWorldHUD] = []
	for index in 2:
		var hud := HUD_SCENE.instantiate() as EnemyWorldHUD
		world.hud_layer.add_child(hud)
		hud.bind_combatant(_enemy_with_state(80 - index * 10, 3))
		hud.set_projected_head_position(Vector2(500 + index * 30, 300))
		hud.set_details_visible(true)
		huds.append(hud)

	world._layout_enemy_huds()

	for hud: EnemyWorldHUD in huds:
		assert_true(hud.details.visible)
		assert_eq(
			hud.details.global_position.y,
			hud.compact_stack.get_global_rect().end.y + DETAILS_GAP,
		)
		assert_eq(hud.details.global_position.x, hud.compact_stack.global_position.x)


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
	assert_eq(defeated_hud.compact_stack.global_position, Vector2(390, 201))
	assert_eq(survivor.compact_stack.global_position, Vector2(390, 201))
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
	assert_eq(survivor.compact_stack.global_position, Vector2(390, 201))


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


func _assert_rounded_style(style: StyleBox) -> void:
	assert_true(style is StyleBoxFlat)
	if not style is StyleBoxFlat:
		return
	var flat := style as StyleBoxFlat
	assert_eq(flat.corner_radius_top_left, 6)
	assert_eq(flat.corner_radius_top_right, 6)
	assert_eq(flat.corner_radius_bottom_right, 6)
	assert_eq(flat.corner_radius_bottom_left, 6)


func _fill_color(bar: ProgressBar) -> Color:
	var fill := bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	return fill.bg_color if fill != null else Color.TRANSPARENT


func _assert_guard_visuals_inside(stack: EnemyGuardStack, bounds: Rect2) -> void:
	for layer: Control in stack.layers:
		for pip: TextureRect in layer.get_children():
			if pip.visible:
				assert_true(bounds.encloses(pip.get_global_rect()))
	if stack.guard_value.visible:
		assert_true(bounds.encloses(stack.guard_value.get_global_rect()))
	if stack.status_label.visible:
		assert_true(bounds.encloses(stack.status_label.get_global_rect()))


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
