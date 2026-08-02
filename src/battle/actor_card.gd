extends Control
class_name ActorCard

enum TargetPresentation { NORMAL, AVAILABLE, SELECTED }

@export var damage_popup_scene: PackedScene
@export var buff_scene: PackedScene
@export var debuff_scene: PackedScene

# --- Signals (Shared by both) ---
signal actor_breached(actor)
signal actor_defeated(actor)
signal actor_revived(actor)
signal hp_changed(new_hp, max_hp)
signal armor_changed(new_pips)
signal actor_conditions_changed
signal spawn_particles(pos, type)
signal target_hovered(actor: ActorCard)
signal target_unhovered(actor: ActorCard)

const MAX_GUARD = 10

# --- UI Node References (Shared) ---
@onready var rich_tooltip: RichTooltip = $Panel/RichTooltip
@onready var name_label: Label = $Panel/Title
@onready var hp_bar_ghost: ProgressBar = $Panel/HP/BarGhost
@onready var hp_bar_actual: ProgressBar = $Panel/HP/BarActual
@onready var panel: Panel = $Panel
@onready var hp_value: Label = $Panel/HP/Value
@onready var guard_bar: HBoxContainer = $Panel/GuardBar
@onready var guard_label: Control = $Panel/GuardLabel
@onready var guard_value: Label = $Panel/GuardLabel/Value
@onready var portrait_rect: TextureRect = $Panel/Portrait
@onready var breached_label: Label = $Panel/BreachedLabel
@onready var highlight_panel: Panel = $Panel/Highlight
@onready var target_outline: Panel = $Panel/TargetOutline
@onready var target_pulse: Panel = $Panel/TargetPulse
@onready var action_display: PanelContainer = $Panel/ActionName
@onready var next_panel: Panel = $Panel/NextPanel
@onready var debuffs_panel: Control = $Debuffs
@onready var buffs_panel: Control = $Buffs
@onready var presentation := $CombatantPresentation as CardCombatantPresentation

var battle_manager: BattleManager
var pip_tweens: Dictionary = {}
var _target_presentation := TargetPresentation.NORMAL
var _target_pulse_tween: Tween
var _combatant: BattleCombatant
var combatant: BattleCombatant:
	get: return _combatant

# --- Data (Shared by both) ---
var actor_name: String:
	get: return _require_combatant().actor_name
	set(value): _require_combatant().actor_name = value
var current_stats: ActorStats:
	get: return _require_combatant().current_stats
	set(value): _require_combatant().current_stats = value
var current_hp: int:
	get: return _require_combatant().current_hp
	set(value): _require_combatant().current_hp = value
var current_guard: int:
	get: return _require_combatant().current_guard
	set(value): _require_combatant().current_guard = value
var current_ct: int:
	get: return _require_combatant().current_ct
	set(value): _require_combatant().current_ct = value
var ct_speed_scale: float:
	get: return _require_combatant().ct_speed_scale
	set(value): _require_combatant().ct_speed_scale = value
var battle_priority: int:
	get: return _require_combatant().battle_priority
	set(value): _require_combatant().battle_priority = value
var is_valid_target: bool:
	get: return _require_combatant().is_valid_target
	set(value): _require_combatant().is_valid_target = value
var is_breached: bool:
	get: return _require_combatant().is_breached
	set(value): _require_combatant().is_breached = value
var is_in_danger: bool:
	get: return _require_combatant().is_in_danger
	set(value): _require_combatant().is_in_danger = value
var is_defeated: bool:
	get: return _require_combatant().is_defeated
	set(value): _require_combatant().is_defeated = value
var active_conditions: Array[Condition]:
	get: return _require_combatant().active_conditions
	set(value): _require_combatant().active_conditions = value
var active_traits: Array[Trait]:
	get: return _require_combatant().active_traits
	set(value): _require_combatant().active_traits = value

# --- Animation Tweens ---
var shake_tween: Tween
var pulse_tween: Tween
var health_tween: Tween
var panel_home_position: Vector2

# -- Popup Settings ---
var last_popup_time: float = 0.0
var popup_stack_offset: int = 0
const POPUP_SPACING_TIME: float = 1.0


func _on_target_mouse_entered() -> void:
	target_hovered.emit(self)


func _on_target_mouse_exited() -> void:
	target_unhovered.emit(self)


func bind_combatant(value: BattleCombatant) -> void:
	assert(value != null, "ActorCard requires a BattleCombatant.")
	assert(_combatant == null, "ActorCard cannot be rebound to another BattleCombatant.")
	_combatant = value
	_ensure_battle_manager()
	presentation.card = self
	presentation.bind(value)
	value.hp_changed.connect(_on_combatant_hp_changed)
	value.guard_changed.connect(_on_combatant_guard_changed)
	value.conditions_changed.connect(_on_combatant_conditions_changed)
	value.danger_changed.connect(_on_combatant_danger_changed)
	value.breached.connect(_on_combatant_breached)
	value.defeated.connect(_on_combatant_defeated)
	value.revived.connect(_on_combatant_revived)
	value.presentation_event.connect(_on_combatant_presentation_event)
	_render_full_state()


func _require_combatant() -> BattleCombatant:
	assert(_combatant != null, "ActorCard requires a bound BattleCombatant.")
	return _combatant


func _ensure_battle_manager() -> void:
	if battle_manager == null and get_parent() != null:
		battle_manager = get_parent().get_node_or_null("%BattleManager") as BattleManager


func _setup_card_visuals() -> void:
	_require_combatant()
	rich_tooltip.bbcode_text = current_stats._to_string()
	hp_bar_ghost.max_value = current_stats.max_hp
	hp_bar_actual.max_value = current_stats.max_hp
	panel_home_position = panel.position
	breached_label.hide()
	highlight_panel.hide()
	hp_bar_ghost.hide()
	update_health_bar()
	hp_bar_actual.value = 0
	hp_value.text = str(0)
	action_display.hide()
	next_panel.hide()
	await get_tree().process_frame

	for pip in guard_bar.get_children():
		pip.get_child(0).set_pivot_offset(pip.size / 2.0)
	update_guard_bar(false)
	set_target_presentation(TargetPresentation.NORMAL)


func _render_full_state() -> void:
	if not is_node_ready():
		return
	rich_tooltip.bbcode_text = current_stats._to_string()
	name_label.text = actor_name
	hp_bar_ghost.max_value = current_stats.max_hp
	hp_bar_actual.max_value = current_stats.max_hp
	hp_bar_ghost.value = current_hp
	hp_bar_actual.value = current_hp
	hp_value.text = Utils.commafy(current_hp)
	update_guard_bar(false)
	_update_conditions_ui()
	if is_defeated:
		_stop_breach_pulse()
		_show_defeated_visual(true)
		return
	if is_breached:
		_render_breach_state(false)
	else:
		_render_danger_state()


func _on_combatant_hp_changed(
	_actor: BattleCombatant,
	value: int,
	max_value: int,
) -> void:
	hp_value.text = Utils.commafy(value)
	hp_changed.emit(value, max_value)


func _on_combatant_guard_changed(_actor: BattleCombatant, value: int) -> void:
	update_guard_bar()
	armor_changed.emit(value)


func _on_combatant_conditions_changed(_actor: BattleCombatant) -> void:
	_update_conditions_ui()
	actor_conditions_changed.emit()


func _on_combatant_danger_changed(
	_actor: BattleCombatant,
	_value: bool,
) -> void:
	_render_danger_state()


func _on_combatant_breached(_actor: BattleCombatant) -> void:
	_render_breach_state(true)
	actor_breached.emit(self)


func _render_breach_state(animate: bool) -> void:
	breached_label.text = "BREACHED"
	guard_bar.modulate.a = 0.25
	if animate:
		_start_breach_pulse()
		shake_panel(1.0)
	else:
		breached_label.show()
		breached_label.self_modulate = Color.WHITE


func _on_combatant_defeated(_actor: BattleCombatant) -> void:
	if breached_label.visible:
		_stop_breach_pulse()
	_show_defeated_visual(false)
	actor_defeated.emit(self)


func _on_combatant_revived(_actor: BattleCombatant) -> void:
	_show_revived_visual()
	actor_revived.emit(self)


func _on_combatant_presentation_event(
	_actor: BattleCombatant,
	event: StringName,
	payload: Dictionary,
) -> void:
	match event:
		&"damage_received":
			hp_bar_actual.value = current_hp
			_spawn_damage_popup(
				payload.result.final_damage,
				payload.damage_type,
				payload.result.is_critical,
			)
			spawn_particles.emit(get_global_rect().get_center(), "gunshot")
		&"healing_received":
			hp_bar_ghost.value = current_hp
		&"impact":
			shake_panel(float(payload.get("intensity", 0.5)))
		&"passive_fired":
			if self is HeroCard:
				(self as HeroCard).passive_fired.emit()


func _render_danger_state() -> void:
	breached_label.text = "VULNERABLE"
	if is_in_danger:
		_start_breach_pulse()
	elif not is_breached:
		_stop_breach_pulse()


func _show_defeated_visual(_immediate: bool = false) -> void:
	pass


func _show_revived_visual() -> void:
	pass

func on_turn_started() -> void:
	next_panel.hide()
	highlight(true)
	await battle_manager.wait(0.1)
	await _fire_condition_event(Trigger.TriggerType.ON_TURN_START)

	return

func on_turn_ended() -> void:
	await battle_manager.wait(0.1)
	await _fire_condition_event(Trigger.TriggerType.ON_TURN_END)
	highlight(false)

func take_one_hit(
	result: DamageResult,
	damage_effect: Effect_Damage,
	attacker: ActorCard,
	resolved_damage_type: Action.DamageType,
) -> int:
	return await _require_combatant().take_one_hit(
		result, damage_effect, attacker, resolved_damage_type,
	)

func in_danger(value: bool):
	await _require_combatant().in_danger(value)

func breach():
	await _require_combatant().breach()

func take_healing(heal_amount: int, is_revive: bool = false):
	await _require_combatant().take_healing(heal_amount, is_revive)

func add_condition(condition_resource: Condition):
	await _require_combatant().add_condition(condition_resource)

func has_condition(condition_name: String) -> bool:
	return _require_combatant().has_condition(condition_name)

func remove_condition(condition_name: String, report_missing: bool = true) -> bool:
	return await _require_combatant().remove_condition(condition_name, report_missing)


func remove_debuffs(quantity: int) -> int:
	return await _require_combatant().remove_debuffs(quantity)

func count_debuffs() -> int:
	return _require_combatant().count_debuffs()

func sync_visual_health() -> Tween:
	var actual_hp = hp_bar_actual.value
	var ghost_hp = hp_bar_ghost.value
	var real_hp = current_hp

	if actual_hp == real_hp and ghost_hp == real_hp:
		return null
	hp_bar_ghost.show()

	var DURATION = 0.5 / battle_manager.battle_speed

	if health_tween and health_tween.is_running():
		health_tween.kill()

	health_tween = create_tween()
	health_tween.set_trans(Tween.TRANS_SINE)
	health_tween.set_ease(Tween.EASE_OUT)

	if actual_hp < real_hp:
		print(actor_name, " animating heal from ", actual_hp, " to ", real_hp)
		health_tween.tween_property(hp_bar_actual, "value", real_hp, DURATION)
		health_tween.parallel().tween_method(
			_update_health_display,
			actual_hp,
			real_hp,
			DURATION
		)
	elif ghost_hp > real_hp:
		print(actor_name, " animating damage from ", ghost_hp, " to ", real_hp)
		health_tween.tween_property(hp_bar_ghost, "value", real_hp, DURATION)
	return health_tween

func _update_health_display(value_from_tween: float):
	hp_value.text = Utils.commafy(roundi(value_from_tween))

# need to add traits here
func _fire_condition_event(event_type: Trigger.TriggerType, context: Dictionary = {}) -> void:
	await _require_combatant()._fire_condition_event(event_type, context)


func _execute_condition_triggers(
	condition: Condition,
	event_type: Trigger.TriggerType,
	context: Dictionary,
) -> void:
	await _require_combatant()._execute_condition_triggers(
		condition, event_type, context,
	)


func _remove_condition_instance(condition: Condition) -> bool:
	return await _require_combatant()._remove_condition_instance(condition)


func _flush_condition_removal_notification() -> void:
	_require_combatant()._flush_condition_removal_notification()

func update_health_bar():
	hp_bar_actual.value = current_hp
	hp_bar_ghost.value = current_hp
	hp_value.text = str(current_hp)

func defeated():
	_require_combatant().defeat()

func recover_breach():
	await _require_combatant().recover_breach()
	guard_bar.modulate.a = 1
	_stop_breach_pulse()

func modify_guard(amount: int, is_recovering: bool = false):
	await _require_combatant().modify_guard(amount, is_recovering)

func is_taunting() -> bool:
	return _require_combatant().is_taunting()

func is_untargetable() -> bool:
	return _require_combatant().is_untargetable()

func update_guard_bar(animate: bool = true):
	guard_value.text = str(current_guard)
	guard_value.position.x = (current_guard -1) * 38
	guard_label.visible = current_guard > 0
	var pips = guard_bar.get_children()

	if pips.is_empty() or pips[0].size.x == 0:
		await get_tree().process_frame

	for i in pips.size():
		var pip_node = pips[i]

		if i < current_guard:
			if not pip_node.visible:
				_animate_pip_gain(pip_node)
		elif pip_node.visible:
			if animate:
				await _animate_pip_loss(pip_node)
			else:
				pip_node.hide()


func show_action(action_name: String):
	var duration = 0.1 / battle_manager.battle_speed
	var label = action_display.get_node("MarginContainer/Label")
	label.text = action_name
	action_display.modulate.a = 0.0
	action_display.show()

	var tween = create_tween()
	tween.tween_property(action_display, "modulate:a", 1.0, duration)

func hide_action():
	var duration = 0.3 / battle_manager.battle_speed
	var tween = create_tween()
	tween.tween_property(action_display, "modulate:a", 0.0, duration)
	await tween.finished.connect(func(): action_display.hide())

func show_next():
	#next_panel.show()
	pass

	#var tween = create_tween()
	#tween.tween_property(next_panel, "modulate:a", 1.0, 0.1 / battle_manager.battle_speed)

func _start_breach_pulse():
	var color = Color.ORANGE_RED
	if is_in_danger:
		color = Color.GOLD
	breached_label.show()
	if pulse_tween: pulse_tween.kill()

	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(
		breached_label,
		"self_modulate",
		color,
		0.5 / battle_manager.battle_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	pulse_tween.tween_property(
		breached_label,
		"self_modulate",
		Color.WHITE,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_breach_pulse():
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

	breached_label.hide()
	breached_label.self_modulate = Color.WHITE

func shake_panel(intensity: float = 0.5):
	var home_position = position
	# Kill old shake if it's running
	if shake_tween and shake_tween.is_running():
		shake_tween.kill()

	# 1. Define shake properties
	var shake_strength = 5.0 + (20.0 * intensity)
	var duration = 0.05

	# 2. Create the tween
	shake_tween = create_tween().set_ease(Tween.EASE_OUT)

	# 3. Add the shake sequence (back-and-forth)
	shake_tween.tween_property(self, "position",
		home_position + Vector2(0, shake_strength), duration)
	shake_tween.tween_property(self, "position",
		home_position + Vector2(0, -shake_strength), duration)
	shake_tween.tween_property(self, "position",
		home_position + Vector2(0, shake_strength / 2), duration)

	# 4. Return to the home position
	shake_tween.tween_property(self, "position",
		home_position, duration)

func _animate_pip_gain(pip_node: Control, animate: bool = true):
	if pip_tweens.has(pip_node):
		pip_tweens[pip_node].kill()
		pip_tweens.erase(pip_node)

	pip_node.show()
	var pip_texture = pip_node.get_child(0)

	if not animate:
		pip_texture.scale = Vector2(1.0, 1.0)
		pip_texture.modulate = Color(1.0, 1.0, 1.0)
		return

	var tween = create_tween()
	tween.set_parallel()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)

	pip_tweens[pip_node] = tween

	pip_texture.scale = Vector2(2.0, 2.0)
	pip_texture.modulate = Color(5.0, 5.0, 5.0)

	tween.tween_property(pip_texture, "scale", Vector2(1.0, 1.0), 0.75)
	tween.tween_property(pip_texture, "modulate", Color(1.0, 1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE)

	tween.finished.connect(func(): pip_tweens.erase(pip_node))

func _animate_pip_loss(pip_node: Control, animate: bool = true):
	if pip_tweens.has(pip_node):
		pip_tweens[pip_node].kill()
		pip_tweens.erase(pip_node)

	if not animate:
		pip_node.hide()
		return

	var tween = create_tween()

	pip_tweens[pip_node] = tween

	tween.tween_property(pip_node, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)

	tween.finished.connect(func():
		pip_node.hide()
		pip_node.modulate.a = 1.0
		pip_tweens.erase(pip_node)
	)

func highlight(value: bool):
	highlight_panel.visible = value

func get_target_presentation() -> TargetPresentation:
	return _target_presentation

func set_target_presentation(state: TargetPresentation) -> void:
	if state == _target_presentation:
		target_outline.visible = state != TargetPresentation.NORMAL
		target_pulse.visible = state == TargetPresentation.SELECTED
		return
	_stop_target_pulse()
	_target_presentation = state
	target_outline.visible = state != TargetPresentation.NORMAL
	target_pulse.visible = state == TargetPresentation.SELECTED
	if state == TargetPresentation.SELECTED:
		target_pulse.modulate.a = 0.0
		_target_pulse_tween = create_tween().set_loops()
		_target_pulse_tween.tween_property(target_pulse, "modulate:a", 0.5, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_target_pulse_tween.tween_property(target_pulse, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_target_pulse() -> void:
	if _target_pulse_tween and _target_pulse_tween.is_valid():
		_target_pulse_tween.kill()
	_target_pulse_tween = null
	target_pulse.modulate.a = 1.0

func _on_gui_input(_event: InputEvent):
	pass

func get_power(power_type: Action.PowerType) -> int:
	return _require_combatant().get_power(power_type)

func get_speed() -> int:
	return _require_combatant().get_speed()

func get_ct_speed() -> int:
	return _require_combatant().get_ct_speed()

func get_action_ct_percent(action: Action) -> int:
	return _require_combatant().get_action_ct_percent(action)

func get_aim() -> int:
	return _require_combatant().get_aim()

func get_incoming_aim_mods() -> int:
	return _require_combatant().get_incoming_aim_mods()

func get_crit_damage_bonus() -> int:
	return _require_combatant().get_crit_damage_bonus()

func get_damage_dealt_modifier(target: ActorCard) -> float:
	return _require_combatant().get_damage_dealt_modifier(target)


func get_damage_dealt_contributions(
	target: ActorCard,
) -> Array[DamageContribution]:
	return _require_combatant().get_damage_dealt_contributions(target)


func get_damage_taken_modifier(attacker: ActorCard) -> float:
	return _require_combatant().get_damage_taken_modifier(attacker)


func get_damage_taken_contributions(
	attacker: ActorCard,
) -> Array[DamageContribution]:
	return _require_combatant().get_damage_taken_contributions(attacker)

func _update_conditions_ui():
	for child in buffs_panel.get_children():
		child.queue_free()
	for child in debuffs_panel.get_children():
		child.queue_free()

	for condition in active_conditions:
		if condition.is_passive: continue
		match condition.condition_type:
			Condition.ConditionType.BUFF:
				var buff = buff_scene.instantiate() as ConditionUI
				buffs_panel.add_child(buff)
				buff.setup(condition)
			Condition.ConditionType.DEBUFF:
				var debuff = debuff_scene.instantiate() as ConditionUI
				debuffs_panel.add_child(debuff)
				debuff.setup(condition)
				pass

func _spawn_damage_popup(amount: int, damage_type: Action.DamageType, is_crit: bool):
	if not damage_popup_scene:
		push_warning("DamagePopupScene not set on ActorCard!")
		return

	# 1. Create the instance
	var popup = damage_popup_scene.instantiate() as DamagePopup

	battle_manager.add_child(popup)

	var target_position = global_position - Vector2(100, 0)

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_popup_time < POPUP_SPACING_TIME:
		popup_stack_offset += 1
		var side = 1 if popup_stack_offset % 2 == 0 else -1
		target_position.x += side * 60  # Offset horizontally
		target_position.y -= popup_stack_offset * 30  # Stack upward
	else:
		popup_stack_offset = 0

	popup.global_position = target_position

	# 4. Update tracking
	last_popup_time = current_time

	popup.show_damage(amount, damage_type, battle_manager.battle_speed, is_crit)
