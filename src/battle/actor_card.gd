extends Control
class_name ActorCard

enum TargetPresentation { NORMAL, AVAILABLE, SELECTED }

@export var damage_popup_scene: PackedScene
@export var buff_scene: PackedScene
@export var debuff_scene: PackedScene

# --- Presentation/input signals ---
signal spawn_particles(pos, type)
signal target_hovered(actor: ActorCard)
signal target_unhovered(actor: ActorCard)

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


func bind_combatant(value: BattleCombatant) -> bool:
	if not is_instance_valid(value):
		push_error("ActorCard requires a valid BattleCombatant.")
		return false
	if _combatant != null:
		push_error("ActorCard cannot be rebound to another BattleCombatant.")
		return false
	if not is_instance_valid(presentation):
		push_error("ActorCard requires a CardCombatantPresentation child.")
		return false
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
	return presentation.combatant == value


func _require_combatant() -> BattleCombatant:
	assert(_combatant != null, "ActorCard requires a bound BattleCombatant.")
	return _combatant


func _ensure_battle_manager() -> void:
	if battle_manager == null and get_parent() != null:
		battle_manager = get_parent().get_node_or_null("%BattleManager") as BattleManager


func _setup_card_visuals() -> void:
	var model := _require_combatant()
	rich_tooltip.bbcode_text = model.current_stats._to_string()
	hp_bar_ghost.max_value = model.current_stats.max_hp
	hp_bar_actual.max_value = model.current_stats.max_hp
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
	var model := _require_combatant()
	rich_tooltip.bbcode_text = model.current_stats._to_string()
	name_label.text = model.actor_name
	hp_bar_ghost.max_value = model.current_stats.max_hp
	hp_bar_actual.max_value = model.current_stats.max_hp
	hp_bar_ghost.value = model.current_hp
	hp_bar_actual.value = model.current_hp
	hp_value.text = Utils.commafy(model.current_hp)
	update_guard_bar(false)
	_update_conditions_ui()
	if model.is_defeated:
		_stop_breach_pulse()
		_show_defeated_visual(true)
		return
	if model.is_breached:
		_render_breach_state(false)
	else:
		_render_danger_state()


func _on_combatant_hp_changed(
	_actor: BattleCombatant,
	value: int,
	max_value: int,
) -> void:
	hp_value.text = Utils.commafy(value)


func _on_combatant_guard_changed(_actor: BattleCombatant, value: int) -> void:
	update_guard_bar()


func _on_combatant_conditions_changed(_actor: BattleCombatant) -> void:
	_update_conditions_ui()


func _on_combatant_danger_changed(
	_actor: BattleCombatant,
	_value: bool,
) -> void:
	_render_danger_state()


func _on_combatant_breached(_actor: BattleCombatant) -> void:
	_render_breach_state(true)


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


func _on_combatant_revived(_actor: BattleCombatant) -> void:
	_show_revived_visual()


func _on_combatant_presentation_event(
	_actor: BattleCombatant,
	event: StringName,
	payload: Dictionary,
) -> void:
	match event:
		&"damage_received":
			hp_bar_actual.value = _require_combatant().current_hp
			_spawn_damage_popup(
				payload.result.final_damage,
				payload.damage_type,
				payload.result.is_critical,
			)
			spawn_particles.emit(get_global_rect().get_center(), "gunshot")
		&"healing_received":
			hp_bar_ghost.value = _require_combatant().current_hp
		&"impact":
			shake_panel(float(payload.get("intensity", 0.5)))


func _render_danger_state() -> void:
	breached_label.text = "VULNERABLE"
	var model := _require_combatant()
	if model.is_in_danger:
		_start_breach_pulse()
	elif not model.is_breached:
		_stop_breach_pulse()


func _show_defeated_visual(_immediate: bool = false) -> void:
	pass


func _show_revived_visual() -> void:
	pass

func sync_visual_health() -> Tween:
	var actual_hp = hp_bar_actual.value
	var ghost_hp = hp_bar_ghost.value
	var real_hp = _require_combatant().current_hp

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
		print(_require_combatant().actor_name, " animating heal from ", actual_hp, " to ", real_hp)
		health_tween.tween_property(hp_bar_actual, "value", real_hp, DURATION)
		health_tween.parallel().tween_method(
			_update_health_display,
			actual_hp,
			real_hp,
			DURATION
		)
	elif ghost_hp > real_hp:
		print(_require_combatant().actor_name, " animating damage from ", ghost_hp, " to ", real_hp)
		health_tween.tween_property(hp_bar_ghost, "value", real_hp, DURATION)
	return health_tween

func _update_health_display(value_from_tween: float):
	hp_value.text = Utils.commafy(roundi(value_from_tween))

func update_health_bar():
	var model := _require_combatant()
	hp_bar_actual.value = model.current_hp
	hp_bar_ghost.value = model.current_hp
	hp_value.text = str(model.current_hp)

func update_guard_bar(animate: bool = true):
	var current_guard := _require_combatant().current_guard
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
	if _require_combatant().is_in_danger:
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

func _update_conditions_ui():
	for child in buffs_panel.get_children():
		child.queue_free()
	for child in debuffs_panel.get_children():
		child.queue_free()

	for condition in _require_combatant().active_conditions:
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
