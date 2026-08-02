extends Control
class_name EnemyWorldHUD

signal hovered
signal unhovered
signal pressed

const COMPACT_SIZE := Vector2(220.0, 78.0)
const HEAD_GAP := 12.0
const TARGET_PADDING := Vector2(18.0, 18.0)
const MIN_TARGET_WIDTH := 96.0

@onready var target_region: Control = %TargetRegion
@onready var details: MarginContainer = %Details
@onready var name_label: Label = %Name
@onready var kinetic_value: Label = %Kinetic
@onready var energy_value: Label = %Energy
@onready var compact_stack: VBoxContainer = %CompactStack
@onready var intent_row: RichTextLabel = %IntentRow
@onready var intent_tooltip: RichTooltip = %IntentTooltip
@onready var vitals_row: HBoxContainer = %VitalsRow
@onready var guard_value: Label = %GuardValue
@onready var hp_bar: TextureProgressBar = %HP
@onready var conditions_row: HBoxContainer = %ConditionsRow

var combatant: EnemyCombatant
var target_state := CombatantPresentation.TargetState.NORMAL
var _hovered := false
var _has_projected_head := false
var _has_projected_foot := false
var _projected_head := Vector2.ZERO
var _projected_foot := Vector2.ZERO
var _details_tween: Tween


func _ready() -> void:
	target_region.mouse_entered.connect(_on_target_mouse_entered)
	target_region.mouse_exited.connect(_on_target_mouse_exited)
	target_region.gui_input.connect(_on_target_gui_input)
	intent_row.mouse_entered.connect(_on_target_mouse_entered)
	intent_row.mouse_exited.connect(_on_target_mouse_exited)
	intent_row.gui_input.connect(_on_target_gui_input)
	details.hide()
	set_process(false)


func _exit_tree() -> void:
	_disconnect_combatant()
	if _details_tween != null and _details_tween.is_valid():
		_details_tween.kill()


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


func set_target_state(state: CombatantPresentation.TargetState) -> void:
	target_state = state
	match state:
		CombatantPresentation.TargetState.NORMAL:
			compact_stack.modulate = Color.WHITE
		CombatantPresentation.TargetState.AVAILABLE:
			compact_stack.modulate = Color(0.65, 1.0, 1.0)
		CombatantPresentation.TargetState.SELECTED:
			compact_stack.modulate = Color(1.0, 0.79, 0.29)
	set_details_visible(_hovered or state == CombatantPresentation.TargetState.SELECTED)


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


func set_projection_visible(value: bool) -> void:
	visible = value and _has_live_combatant()
	target_region.mouse_filter = Control.MOUSE_FILTER_STOP \
		if visible else Control.MOUSE_FILTER_IGNORE


func has_valid_projection() -> bool:
	return _has_projected_head and visible and _has_live_combatant()


func get_desired_compact_rect() -> Rect2:
	if not _has_projected_head:
		return Rect2(global_position, COMPACT_SIZE)
	return Rect2(
		Vector2(
			_projected_head.x - COMPACT_SIZE.x * 0.5,
			_projected_head.y - HEAD_GAP - COMPACT_SIZE.y,
		),
		COMPACT_SIZE,
	)


func apply_resolved_compact_rect(rect: Rect2) -> void:
	global_position = rect.position
	_sync_target_region()


func refresh_intent() -> void:
	if not is_instance_valid(combatant):
		intent_row.text = ""
		intent_tooltip.bbcode_text = ""
		return
	var formatted := EnemyIntentFormatter.format(combatant, combatant.battle_manager)
	intent_row.text = formatted.text
	intent_tooltip.bbcode_text = formatted.tooltip


func get_target_rect() -> Rect2:
	return target_region.get_global_rect()


func _connect_combatant() -> void:
	combatant.hp_changed.connect(_on_hp_changed)
	combatant.guard_changed.connect(_on_guard_changed)
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
	kinetic_value.text = "KIN %d%%" % combatant.current_stats.kinetic_defense
	energy_value.text = "NRG %d%%" % combatant.current_stats.energy_defense
	_render_hp()
	_render_guard()
	_render_conditions()
	refresh_intent()


func _render_hp() -> void:
	hp_bar.max_value = combatant.current_stats.max_hp
	hp_bar.value = combatant.current_hp
	hp_bar.tooltip_text = "%d / %d HP" % [
		combatant.current_hp, combatant.current_stats.max_hp,
	]


func _render_guard() -> void:
	guard_value.text = str(combatant.current_guard)


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


func _on_conditions_changed(_enemy: BattleCombatant) -> void:
	_render_conditions()


func _on_presentation_event(
	_enemy: BattleCombatant,
	event: StringName,
	_payload: Dictionary,
) -> void:
	if event == &"intent_changed":
		refresh_intent()


func _on_combatant_defeated(enemy: BattleCombatant) -> void:
	if enemy == combatant:
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
	set_details_visible(target_state == CombatantPresentation.TargetState.SELECTED)
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
	var target_rect := Rect2(global_position, COMPACT_SIZE).grow(TARGET_PADDING.x)
	if _has_projected_head and _has_projected_foot:
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
	target_region.global_position = target_rect.position
	target_region.size = target_rect.size


func _invalidate_projection() -> void:
	_has_projected_head = false
	_has_projected_foot = false
	_hovered = false
	set_details_visible(false)
	visible = false
	target_region.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _has_live_combatant() -> bool:
	return is_instance_valid(combatant) and not combatant.is_defeated


func _is_interactive() -> bool:
	return _has_live_combatant() \
		and visible \
		and target_region.mouse_filter == Control.MOUSE_FILTER_STOP
