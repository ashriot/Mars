extends Control
class_name EnemyWorldHUD

signal hovered
signal unhovered
signal pressed

const COMPACT_WIDTH := 220.0
const INTENT_WIDTH := 286.0
const DETAILS_SIZE := Vector2(220.0, 74.0)
const DETAILS_GAP := 4.0
const HEAD_GAP := 12.0
const GUARD_TOP := 28.0
const TARGET_PADDING := Vector2(18.0, 18.0)
const MIN_TARGET_WIDTH := 96.0
const POPUP_SPACING_TIME_MSEC := 1000
const POPUP_HORIZONTAL_STEP := 60.0
const POPUP_VERTICAL_STEP := 30.0

@export var damage_popup_scene: PackedScene

@onready var target_region: Control = %TargetRegion
@onready var details: Control = %Details
@onready var name_label: Label = %Name
@onready var kinetic_value: Label = %Kinetic
@onready var energy_value: Label = %Energy
@onready var compact_stack: VBoxContainer = %CompactStack
@onready var intent_row: RichTextLabel = %IntentRow
@onready var intent_tooltip: RichTooltip = %IntentTooltip
@onready var vitals_group: Control = %VitalsGroup
@onready var guard_stack: EnemyGuardStack = %GuardStack
@onready var hp_region: Control = %HPRegion
@onready var hp_bar_feedback: ProgressBar = %HPFeedback
@onready var hp_bar_actual: ProgressBar = %HPActual
@onready var hp_value: Label = %HPValue
@onready var conditions_row: HBoxContainer = %ConditionsRow

var combatant: EnemyCombatant
var target_state := CombatantPresentation.TargetState.NORMAL
var _hovered := false
var _has_projected_head := false
var _has_projected_foot := false
var _projected_head := Vector2.ZERO
var _projected_foot := Vector2.ZERO
var _projected_model_bounds := Rect2()
var _safe_rect := Rect2()
var _has_projected_model_bounds := false
var _details_tween: Tween
var _health_tween: Tween
var _presentation_owns_defeat_fade := false
var _last_popup_time_msec := -POPUP_SPACING_TIME_MSEC
var _popup_stack_offset := 0


func _ready() -> void:
	target_region.mouse_entered.connect(_on_target_mouse_entered)
	target_region.mouse_exited.connect(_on_target_mouse_exited)
	target_region.gui_input.connect(_on_target_gui_input)
	intent_row.mouse_entered.connect(_on_target_mouse_entered)
	intent_row.mouse_exited.connect(_on_target_mouse_exited)
	intent_row.gui_input.connect(_on_target_gui_input)
	hp_region.mouse_entered.connect(_on_target_mouse_entered)
	hp_region.mouse_exited.connect(_on_target_mouse_exited)
	hp_region.gui_input.connect(_on_target_gui_input)
	details.hide()
	_sync_compact_height()
	_sync_details_position()
	set_process(false)


func _exit_tree() -> void:
	_disconnect_combatant()
	if _details_tween != null and _details_tween.is_valid():
		_details_tween.kill()
	if _health_tween != null and _health_tween.is_valid():
		_health_tween.kill()


func bind_combatant(enemy: EnemyCombatant) -> bool:
	if not is_instance_valid(enemy):
		push_error("EnemyWorldHUD requires a valid EnemyCombatant.")
		return false
	if combatant != null:
		push_error("EnemyWorldHUD cannot be rebound to another combatant.")
		return false
	combatant = enemy
	_connect_combatant()
	_render_full_state()
	return true


func enable_presentation_owned_defeat_fade() -> void:
	_presentation_owns_defeat_fade = true


func begin_presentation_owned_defeat_fade() -> void:
	if _presentation_owns_defeat_fade:
		_invalidate_projection(true)


func complete_presentation_owned_defeat_fade() -> void:
	if not _presentation_owns_defeat_fade:
		return
	visible = false
	target_region.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_target_state(state: CombatantPresentation.TargetState) -> void:
	target_state = state
	match state:
		CombatantPresentation.TargetState.NORMAL:
			compact_stack.modulate = Color.WHITE
		CombatantPresentation.TargetState.AVAILABLE:
			compact_stack.modulate = Color(0.65, 1.0, 1.0)
		CombatantPresentation.TargetState.SELECTED:
			compact_stack.modulate = Color(1.0, 0.79, 0.29)


func set_details_visible(value: bool) -> void:
	value = value and _has_live_combatant()
	if _details_tween != null and _details_tween.is_valid():
		_details_tween.kill()
		_details_tween = null
	if not value:
		details.hide()
		details.modulate.a = 0.0
		return
	if details.visible and is_equal_approx(details.modulate.a, 1.0):
		return
	details.show()
	_sync_details_position()
	details.modulate.a = 0.0
	_details_tween = create_tween()
	_details_tween.tween_property(details, "modulate:a", 1.0, 0.12)


func set_projected_head_position(value: Vector2) -> void:
	_projected_head = value
	_has_projected_head = value.is_finite()
	set_projection_visible(_has_projected_head)
	if _has_projected_head:
		apply_resolved_compact_rect(get_desired_compact_rect())


func set_projected_foot_position(value: Vector2) -> void:
	_projected_foot = value
	_has_projected_foot = value.is_finite()
	_sync_target_region()


func set_projected_model_bounds(value: Rect2) -> void:
	_projected_model_bounds = value.abs()
	_has_projected_model_bounds = value.position.is_finite() \
		and value.size.is_finite() \
		and value.size.x > 0.0 \
		and value.size.y > 0.0
	_sync_target_region()


func set_safe_rect(value: Rect2) -> void:
	_safe_rect = value
	_sync_target_region()


func set_projection_visible(value: bool) -> void:
	visible = value and _has_live_combatant()
	target_region.mouse_filter = Control.MOUSE_FILTER_STOP \
		if visible else Control.MOUSE_FILTER_IGNORE


func has_valid_projection() -> bool:
	return _has_projected_head and visible and _has_live_combatant()


func is_hovered() -> bool:
	return _hovered


func get_desired_compact_rect() -> Rect2:
	var compact_size := _get_compact_size()
	if not _has_projected_head:
		return Rect2(global_position, compact_size)
	return Rect2(
		Vector2(
			_projected_head.x - compact_size.x * 0.5,
			_projected_head.y - HEAD_GAP - compact_size.y,
		),
		compact_size,
	)


func apply_resolved_compact_rect(rect: Rect2) -> void:
	global_position = rect.position
	_sync_target_region()


func get_visible_layout_rect() -> Rect2:
	var compact_rect := Rect2(compact_stack.global_position, _get_compact_size())
	if not details.visible:
		return compact_rect
	return get_reserved_layout_rect(compact_rect)


func get_reserved_layout_rect(compact_rect: Rect2) -> Rect2:
	var reserved := compact_rect.merge(_get_intent_layout_rect(compact_rect))
	var guard_visual := guard_stack.get_visual_rect()
	if guard_visual.has_area():
		var guard_offset := guard_stack.global_position - compact_stack.global_position
		reserved = reserved.merge(Rect2(
			compact_rect.position + guard_offset + guard_visual.position,
			guard_visual.size,
		))
	return reserved.merge(Rect2(compact_rect.position + details.position, DETAILS_SIZE))


func refresh_intent() -> void:
	if not is_instance_valid(combatant):
		intent_row.text = ""
		intent_tooltip.bbcode_text = ""
		return
	var formatted := EnemyIntentFormatter.format(combatant, combatant.battle_manager)
	intent_row.text = "[center]%s[/center]" % formatted.text
	intent_tooltip.bbcode_text = formatted.tooltip


func get_target_rect() -> Rect2:
	return target_region.get_global_rect()


func sync_visual_health() -> Tween:
	if not is_instance_valid(combatant):
		return null
	var actual_hp := hp_bar_actual.value
	var feedback_hp := hp_bar_feedback.value
	var authoritative_hp := float(combatant.current_hp)
	if is_equal_approx(actual_hp, authoritative_hp) \
		and is_equal_approx(feedback_hp, authoritative_hp):
		return null
	if _health_tween != null and _health_tween.is_valid():
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.set_trans(Tween.TRANS_SINE)
	_health_tween.set_ease(Tween.EASE_OUT)
	var duration := 0.5 / _get_battle_speed()
	if actual_hp < authoritative_hp:
		_health_tween.tween_property(hp_bar_actual, "value", authoritative_hp, duration)
	elif feedback_hp > authoritative_hp:
		_health_tween.tween_property(hp_bar_feedback, "value", authoritative_hp, duration)
	return _health_tween


func _connect_combatant() -> void:
	combatant.hp_changed.connect(_on_hp_changed)
	combatant.guard_changed.connect(_on_guard_changed)
	combatant.danger_changed.connect(_on_danger_changed)
	combatant.breached.connect(_on_breached)
	combatant.conditions_changed.connect(_on_conditions_changed)
	combatant.presentation_event.connect(_on_presentation_event)
	combatant.defeated.connect(_on_combatant_defeated)
	combatant.tree_exiting.connect(_on_combatant_tree_exiting)


func _disconnect_combatant() -> void:
	if not is_instance_valid(combatant):
		combatant = null
		return
	if combatant.hp_changed.is_connected(_on_hp_changed):
		combatant.hp_changed.disconnect(_on_hp_changed)
	if combatant.guard_changed.is_connected(_on_guard_changed):
		combatant.guard_changed.disconnect(_on_guard_changed)
	if combatant.danger_changed.is_connected(_on_danger_changed):
		combatant.danger_changed.disconnect(_on_danger_changed)
	if combatant.breached.is_connected(_on_breached):
		combatant.breached.disconnect(_on_breached)
	if combatant.conditions_changed.is_connected(_on_conditions_changed):
		combatant.conditions_changed.disconnect(_on_conditions_changed)
	if combatant.presentation_event.is_connected(_on_presentation_event):
		combatant.presentation_event.disconnect(_on_presentation_event)
	if combatant.defeated.is_connected(_on_combatant_defeated):
		combatant.defeated.disconnect(_on_combatant_defeated)
	if combatant.tree_exiting.is_connected(_on_combatant_tree_exiting):
		combatant.tree_exiting.disconnect(_on_combatant_tree_exiting)
	combatant = null


func _render_full_state() -> void:
	name_label.text = combatant.actor_name
	kinetic_value.text = "KIN%d%%" % combatant.current_stats.kinetic_defense
	energy_value.text = "NRG%d%%" % combatant.current_stats.energy_defense
	_render_hp(true)
	_render_guard()
	_render_conditions()
	refresh_intent()


func _render_hp(reset_visual_values := false) -> void:
	hp_bar_feedback.max_value = combatant.current_stats.max_hp
	hp_bar_actual.max_value = combatant.current_stats.max_hp
	hp_value.text = "%d / %d" % [
		combatant.current_hp, combatant.current_stats.max_hp,
	]
	hp_region.tooltip_text = "%d / %d HP" % [
		combatant.current_hp, combatant.current_stats.max_hp,
	]
	if reset_visual_values:
		hp_bar_feedback.value = combatant.current_hp
		hp_bar_actual.value = combatant.current_hp


func _render_guard() -> void:
	guard_stack.render(
		combatant.current_guard,
		combatant.is_in_danger,
		combatant.is_breached,
	)
	_sync_compact_height()
	call_deferred(&"_sync_details_position")


func _render_conditions() -> void:
	for child: Node in conditions_row.get_children():
		child.free()
	for condition: Condition in combatant.active_conditions:
		if condition.is_passive:
			continue
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18.0, 18.0)
		icon.texture = condition.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		conditions_row.add_child(icon)
		var tooltip := RichTooltip.new()
		tooltip.name = "RichTooltip"
		tooltip.bbcode_text = "%s\n%s" % [
			condition.condition_name.to_upper(), condition.description,
		]
		icon.add_child(tooltip)


func _on_hp_changed(_enemy: BattleCombatant, _hp: int, _max_hp: int) -> void:
	_render_hp()


func _on_guard_changed(_enemy: BattleCombatant, _guard: int) -> void:
	_render_guard()


func _on_danger_changed(_enemy: BattleCombatant, _is_in_danger: bool) -> void:
	_render_guard()


func _on_breached(_enemy: BattleCombatant) -> void:
	_render_guard()


func _on_conditions_changed(_enemy: BattleCombatant) -> void:
	_render_conditions()


func _on_presentation_event(
	_enemy: BattleCombatant,
	event: StringName,
	payload: Dictionary,
) -> void:
	match event:
		&"damage_received":
			HealthFeedbackPalette.apply(
				hp_bar_feedback, HealthFeedbackPalette.Direction.DAMAGE,
			)
			hp_bar_actual.value = combatant.current_hp
			var result := payload.get("result") as DamageResult
			if result != null and payload.has("damage_type"):
				var damage_type: Action.DamageType = payload["damage_type"]
				_spawn_damage_popup(result, damage_type)
		&"healing_received":
			HealthFeedbackPalette.apply(
				hp_bar_feedback, HealthFeedbackPalette.Direction.HEALING,
			)
			hp_bar_feedback.value = combatant.current_hp
		&"intent_changed":
			refresh_intent()


func _get_damage_popup_center() -> Variant:
	if not visible or not _has_live_combatant():
		return null
	if _has_projected_model_bounds:
		return _projected_model_bounds.get_center()
	if _has_projected_head and _has_projected_foot:
		return (_projected_head + _projected_foot) * 0.5
	return null


func _spawn_damage_popup(
	result: DamageResult,
	damage_type: Action.DamageType,
) -> void:
	if damage_popup_scene == null or not _has_live_combatant():
		return
	var popup_center: Variant = _get_damage_popup_center()
	if popup_center == null or get_parent() == null:
		return
	var popup := damage_popup_scene.instantiate() as DamagePopup
	if popup == null:
		return
	get_parent().add_child(popup)
	var target_center: Vector2 = popup_center
	var current_time_msec := Time.get_ticks_msec()
	if current_time_msec - _last_popup_time_msec < POPUP_SPACING_TIME_MSEC:
		_popup_stack_offset += 1
		var side := 1.0 if _popup_stack_offset % 2 == 0 else -1.0
		target_center.x += side * POPUP_HORIZONTAL_STEP
		target_center.y -= float(_popup_stack_offset) * POPUP_VERTICAL_STEP
	else:
		_popup_stack_offset = 0
	popup.global_position = target_center - popup.pivot_offset
	_last_popup_time_msec = current_time_msec
	popup.show_damage(
		result.final_damage, damage_type, _get_battle_speed(), result.is_critical,
	)


func _on_combatant_defeated(enemy: BattleCombatant) -> void:
	if enemy == combatant:
		if _presentation_owns_defeat_fade:
			begin_presentation_owned_defeat_fade()
		else:
			_invalidate_projection()


func _on_combatant_tree_exiting() -> void:
	_invalidate_projection()
	_disconnect_combatant()


func _on_target_mouse_entered() -> void:
	if not _is_interactive():
		return
	_hovered = true
	set_details_visible(true)
	hovered.emit()


func _on_target_mouse_exited() -> void:
	if not _is_interactive():
		return
	_hovered = false
	set_details_visible(false)
	unhovered.emit()


func _on_target_gui_input(event: InputEvent) -> void:
	if not _is_interactive():
		return
	if event is InputEventMouseButton \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
		and (event as InputEventMouseButton).pressed:
		pressed.emit()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		pressed.emit()
		accept_event()


func _sync_target_region() -> void:
	var target_rect := Rect2(global_position, _get_compact_size()).grow(TARGET_PADDING.x)
	if _has_projected_model_bounds:
		target_rect = _projected_model_bounds.grow(TARGET_PADDING.x)
	elif _has_projected_head and _has_projected_foot:
		var top := minf(_projected_head.y, _projected_foot.y) - TARGET_PADDING.y
		var bottom := maxf(_projected_head.y, _projected_foot.y) + TARGET_PADDING.y
		var center_x := (_projected_head.x + _projected_foot.x) * 0.5
		var half_width := maxf(
			MIN_TARGET_WIDTH * 0.5,
			absf(_projected_head.x - _projected_foot.x) * 0.5 + TARGET_PADDING.x,
		)
		target_rect = Rect2(
			Vector2(center_x - half_width, top),
			Vector2(half_width * 2.0, bottom - top),
		)
	if _safe_rect.size.x > 0.0 and _safe_rect.size.y > 0.0:
		target_rect = target_rect.intersection(_safe_rect)
	target_region.global_position = target_rect.position
	target_region.size = target_rect.size


func _sync_compact_height() -> void:
	vitals_group.custom_minimum_size.y = GUARD_TOP + guard_stack.custom_minimum_size.y
	var compact_size := _get_compact_size()
	compact_stack.size = compact_size
	custom_minimum_size = compact_size
	size = compact_size


func _sync_details_position() -> void:
	details.size = DETAILS_SIZE
	details.position = Vector2(0.0, -DETAILS_SIZE.y - DETAILS_GAP)


func _get_intent_layout_rect(compact_rect: Rect2) -> Rect2:
	return Rect2(
		Vector2(compact_rect.get_center().x - INTENT_WIDTH * 0.5, compact_rect.position.y),
		Vector2(INTENT_WIDTH, intent_row.size.y),
	)


func _get_compact_size() -> Vector2:
	return Vector2(COMPACT_WIDTH, compact_stack.get_combined_minimum_size().y)


func _get_battle_speed() -> float:
	if is_instance_valid(combatant) and is_instance_valid(combatant.battle_manager):
		return combatant.battle_manager.battle_speed
	return 1.0


func _invalidate_projection(keep_render_surface := false) -> void:
	_has_projected_head = false
	_has_projected_foot = false
	_has_projected_model_bounds = false
	_hovered = false
	set_details_visible(false)
	if not keep_render_surface:
		visible = false
	target_region.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _has_live_combatant() -> bool:
	return is_instance_valid(combatant) and not combatant.is_defeated


func _is_interactive() -> bool:
	return _has_live_combatant() \
		and visible \
		and target_region.mouse_filter == Control.MOUSE_FILTER_STOP
