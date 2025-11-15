extends Control
class_name ActorCard

@export var damage_popup_scene: PackedScene

# --- Signals (Shared by both) ---
signal actor_breached(actor)
signal actor_defeated(actor)
signal actor_revived(actor)
signal hp_changed(new_hp, max_hp)
signal armor_changed(new_pips)
signal actor_conditions_changed(actor, retarget)

const MAX_GUARD = 10

var battle_manager: BattleManager
var flash_tween: Tween
var is_valid_target: bool
var pip_tweens: Dictionary = {}


# --- Data (Shared by both) ---
var actor_name: String
var stat_mods: Dictionary
var stat_scalars: Dictionary
var current_hp: int
var current_guard: int
var current_ct: int = 0
var is_breached: bool
var is_defeated: bool
var active_conditions: Array[Condition] = []
var current_stats: ActorStats

# --- Animation Tweens ---
var shake_tween: Tween
var pulse_tween: Tween
var health_tween: Tween
var panel_home_position: Vector2

# -- Popup Settings ---
var last_popup_time: float = 0.0
var popup_stack_offset: int = 0
const POPUP_SPACING_TIME: float = 1.0

# --- UI Node References (Shared) ---
@onready var name_label: Label = $Panel/Title
@onready var hp_bar_ghost: ProgressBar = $Panel/HP/BarGhost
@onready var hp_bar_actual: ProgressBar = $Panel/HP/BarActual
@onready var panel: Panel = $Panel
@onready var hp_value: Label = $Panel/HP/Value
@onready var guard_bar: HBoxContainer = $Panel/GuardBar
@onready var portrait_rect: TextureRect = $Panel/Portrait
@onready var breached_label: Label = $Panel/BreachedLabel
@onready var highlight_panel: Panel = $Panel/Highlight
@onready var target_flash: Panel = $Panel/TargetFlash
@onready var action_display: PanelContainer = $Panel/ActionName


func setup_base(stats: ActorStats):
	if not stats:
		push_error("ActorCard was given null stats!")
		return
	battle_manager = get_parent().get_node("%BattleManager")
	current_stats = stats.duplicate()
	actor_name = stats.actor_name
	hp_bar_ghost.max_value = current_stats.max_hp
	current_hp = current_stats.max_hp
	hp_bar_actual.max_value = current_stats.max_hp
	hp_bar_ghost.max_value = current_stats.max_hp
	current_guard = current_stats.guard
	panel_home_position = panel.position
	breached_label.hide()
	is_defeated = false
	is_breached = false
	highlight_panel.hide()
	target_flash.hide()
	target_flash.modulate.a = 0.2
	update_health_bar()
	action_display.hide()
	await get_tree().process_frame

	for pip in guard_bar.get_children():
		pip.get_child(0).set_pivot_offset(pip.size / 2.0)
	update_guard_bar(false)

func on_turn_started() -> void:
	await battle_manager.wait(0.1)
	highlight(true)
	await _fire_condition_event(Trigger.TriggerType.ON_TURN_START)

	if is_breached:
		recover_breach()
	return

func on_turn_ended() -> void:
	await battle_manager.wait(0.1)
	highlight(false)
	await _fire_condition_event(Trigger.TriggerType.ON_TURN_END)

func apply_one_hit(damage_effect: Effect_Damage, attacker: ActorCard, dynamic_potency: float) -> void:
	if is_defeated: return
	var is_piercing = damage_effect.damage_type == Action.DamageType.PIERCING

	var is_crit: bool = false
	var crit_chance: int = attacker.get_precision()
	if randi_range(1, 100) <= crit_chance:
		is_crit = true

	if is_piercing:
		shake_panel()
	elif current_guard == 0:
		if not is_breached and damage_effect.shreds_guard:
			breached()
		else:
			shake_panel()
	elif damage_effect.shreds_guard:
		current_guard -= 1
		current_guard = clamp(current_guard, 0, MAX_GUARD)
		print("Current guard is: ", current_guard)
	shake_panel()

	var power_for_hit = attacker.get_power(damage_effect.power_type)
	if is_breached:
		power_for_hit += attacker.current_stats.overload

	var base_hit_damage: float = power_for_hit * dynamic_potency

	if is_crit:
		print("Critical Hit!")
		var crit_bonus: float = 0.0
		crit_bonus = attacker.get_crit_damage_bonus(is_piercing)
		base_hit_damage *= (1.0 + crit_bonus)

	var final_dmg_float = float(base_hit_damage)
	var def_mod = 1.0 if not is_crit else 0.0
	if is_breached:
		def_mod = 0.5
	if damage_effect.damage_type == Action.DamageType.KINETIC:
		final_dmg_float *= (1.0 - float(current_stats.kinetic_defense * def_mod) / 100)
	elif damage_effect.damage_type == Action.DamageType.ENERGY:
		final_dmg_float *= (1.0 - float(current_stats.energy_defense * def_mod) / 100)

	final_dmg_float *= attacker.get_damage_dealt_scalar()
	final_dmg_float *= get_damage_taken_scalar()
	var final_damage = max(0, int(final_dmg_float))
	var up = attacker is EnemyCard
	_spawn_damage_popup(final_damage, up, is_crit)

	current_hp = max(0, current_hp - final_damage)
	hp_bar_actual.value = current_hp
	hp_value.text = str(current_hp)
	hp_changed.emit(current_hp, current_stats.max_hp)
	print("Hit for ", final_damage, " damage! (", base_hit_damage, ")")
	update_guard_bar()

	if current_hp == 0:
		await defeated()
		return
	var context = { }
	if damage_effect.damage_type == Action.DamageType.KINETIC:
		context.get_or_add("targets", [self])
		await _fire_condition_event(Trigger.TriggerType.ON_TAKING_KINETIC_DAMAGE, context)
	elif damage_effect.damage_type == Action.DamageType.ENERGY:
		context.get_or_add("targets", [self])
		await _fire_condition_event(Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE, context)
	await _fire_condition_event(Trigger.TriggerType.ON_BEING_HIT, context)

	return

func breached():
	guard_bar.modulate.a = 0.5
	is_breached = true
	current_ct = 0
	actor_breached.emit()
	_start_breach_pulse()
	shake_panel(1.0)
	await _fire_condition_event(Trigger.TriggerType.ON_BREACHED)

func take_healing(heal_amount: int, is_revive: bool = false):
	if (is_defeated and not is_revive) or heal_amount <= 0:
		return

	var new_hp = min(current_stats.max_hp, current_hp + heal_amount)

	current_hp = new_hp
	print(actor_name, " healed for ", heal_amount, ". HP is now: ", current_hp)
	hp_bar_ghost.value = new_hp
	hp_changed.emit(current_hp, current_stats.max_hp)

func add_condition(condition_resource: Condition):
	if not condition_resource:
		push_error("add_condition was called with a null resource!")
		return

	if has_condition(condition_resource.condition_name):
		print(actor_name, " already has ", condition_resource.condition_name)
		return

	var new_condition = condition_resource.duplicate(true)
	new_condition.attacker = condition_resource.attacker
	active_conditions.append(new_condition)
	print(actor_name, " gained condition: ", new_condition.condition_name)

	await _fire_condition_event(Trigger.TriggerType.ON_APPLIED)
	actor_conditions_changed.emit(self, new_condition.retarget)

func has_condition(condition_name: String) -> bool:
	for condition in active_conditions:
		if condition.condition_name == condition_name:
			return true

	return false

func remove_condition(condition_name: String):
	for condition in active_conditions:
		if condition.condition_name == condition_name:
			active_conditions.erase(condition)
			print(actor_name, " is removing condition: ", condition.condition_name)

			return

	push_error("[ERROR] Trying to remove an invalid condition: ", actor_name, " -> ", condition_name)
	return

func count_debuffs() -> int:
	var count = 0
	for c in active_conditions:
		if c.condition_type == Condition.ConditionType.DEBUFF and not c.is_passive:
			count += 1
	return count

func sync_visual_health() -> Tween:
	var actual_hp = hp_bar_actual.value
	var ghost_hp = hp_bar_ghost.value
	var real_hp = current_hp

	if actual_hp == real_hp and ghost_hp == real_hp:
		return null

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
	hp_value.text = str(roundi(value_from_tween))

func _fire_condition_event(event_type: Trigger.TriggerType, context: Dictionary = {}) -> void:
	for i in range(active_conditions.size() - 1, -1, -1):
		var condition = active_conditions[i] as Condition
		var is_attack = false
		var is_removing = condition.remove_on_triggers.has(event_type)
		for trigger in condition.triggers:
			trigger = trigger as Trigger
			if trigger.trigger_type != event_type: continue
			if is_removing:
				print(actor_name, "'s ", condition.condition_name, " needs to be removed.")
				await _fire_condition_event(Trigger.TriggerType.ON_REMOVED)
				remove_condition(condition.condition_name)
			if condition.is_passive and not is_removing:
				if self is HeroCard and trigger.is_attack:
					self.passive_fired.emit()
			if trigger.is_attack:
				is_attack = true
			await battle_manager.wait(0.25)
			print("Condition '", condition.condition_name, "' is firing effects for '", event_type, "'")
			var targets = []
			var attacker = self
			if condition.attacker:
				attacker = condition.attacker
			var action = context.get("action")
			if context.has("targets"):
				targets = context.targets
			for effect in trigger.effects_to_run:
				effect = effect as ActionEffect
				if targets.is_empty():
					targets = battle_manager.get_targets(effect.target_type, self is HeroCard, targets)
				await battle_manager.execute_triggered_effect(attacker, effect, targets, action)
				await battle_manager._flush_all_health_animations()

func update_health_bar():
	hp_bar_actual.value = current_hp
	hp_bar_ghost.value = current_hp
	hp_value.text = str(current_hp)

func defeated():
	if is_defeated:
		push_error("Defeated twice!!!!")
		return

	print(actor_name, " is defeated!")
	is_defeated = true
	current_ct = 0

	if breached_label and breached_label.visible:
		_stop_breach_pulse()

	actor_defeated.emit(self)

func recover_breach():
	is_breached = false
	guard_bar.modulate.a = 1
	_stop_breach_pulse()
	modify_guard(current_stats.guard)

func modify_guard(amount: int):
	current_guard = clamp(current_guard + amount, 0, MAX_GUARD)

	print(actor_name, " gained ", amount, " guard. Total: ", current_guard)
	await _fire_condition_event(Trigger.TriggerType.ON_GAINING_GUARD)
	update_guard_bar()

func update_guard_bar(animate: bool = true):
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

	armor_changed.emit(current_guard)

func show_action(action_name: String):
	var duration = 0.1 / battle_manager.battle_speed
	var label = action_display.get_node("MarginContainer/Label")
	label.text = action_name.to_upper()
	action_display.modulate.a = 0.0
	action_display.show()

	var tween = create_tween()
	tween.tween_property(action_display, "modulate:a", 1.0, duration)

func hide_action():
	var duration = 0.3 / battle_manager.battle_speed
	var tween = create_tween()
	tween.tween_property(action_display, "modulate:a", 0.0, duration)
	await tween.finished.connect(func(): action_display.hide())

func _start_breach_pulse():
	breached_label.show()
	if pulse_tween: pulse_tween.kill()

	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(
		breached_label,
		"self_modulate",
		Color.ORANGE_RED,
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
	if not panel or intensity == 0.0:
		return

	# Kill old shake if it's running
	if shake_tween and shake_tween.is_running():
		shake_tween.kill()

	# 1. Define shake properties
	var shake_strength = 5.0 + (20.0 * intensity) # 5 px min, 25 px max
	var duration = 0.05

	# 2. Create the tween
	shake_tween = create_tween().set_ease(Tween.EASE_OUT)

	# 3. Add the shake sequence (back-and-forth)
	shake_tween.tween_property(panel, "position",
		panel_home_position + Vector2(0, shake_strength), duration)
	shake_tween.tween_property(panel, "position",
		panel_home_position + Vector2(0, -shake_strength), duration)
	shake_tween.tween_property(panel, "position",
		panel_home_position + Vector2(0, shake_strength / 2), duration)

	# 4. Return to the home position
	shake_tween.tween_property(panel, "position",
		panel_home_position, duration)

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

func start_flashing():
	is_valid_target = true
	target_flash.modulate.a = 0
	target_flash.visible = true

	# Kill old tween if it's running
	if flash_tween and flash_tween.is_running():
		flash_tween.kill()

	flash_tween = create_tween().set_loops()

	flash_tween.tween_property(
		target_flash,
		"modulate:a",
		0.6,
		0.2 / battle_manager.battle_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	flash_tween.tween_property(
		target_flash,
		"modulate:a",
		0.2,
		0.6 / battle_manager.battle_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_flashing():
	is_valid_target = false
	if flash_tween and flash_tween.is_running():
		flash_tween.kill()
		flash_tween = null

	if target_flash:
		target_flash.visible = false
		target_flash.modulate.a = 0.2

func _on_gui_input(_event: InputEvent):
	pass

func get_power(power_type: Action.PowerType) -> int:
	print(actor_name, "'s ATK is: ", current_stats.attack)
	if power_type == Action.PowerType.ATTACK:
		return current_stats.attack
	elif power_type == Action.PowerType.PSYCHE:
		return current_stats.psyche
	return 0

func get_speed() -> int:
	var scalar: float = 1.0
	for condition in active_conditions:
		scalar += condition.speed_scalar
	return int(current_stats.speed * scalar)

func get_precision() -> int:
	var mod: int = 0
	for condition in active_conditions:
		mod += condition.precision_mod

	return current_stats.precision + mod

func get_crit_damage_bonus(is_piercing:= false) -> float:
	if is_piercing:
		return float(current_stats.precision) / 100
	else:
		return 0.0

func get_damage_dealt_scalar() -> float:
	var scalar: float = 1.0
	for condition in active_conditions:
		scalar += condition.damage_dealt_scalar
	return scalar

func get_damage_taken_scalar() -> float:
	var scalar: float = 1.0
	for condition in active_conditions:
		scalar += condition.damage_taken_scalar
	return scalar

func _spawn_damage_popup(amount: int, up: bool, is_crit: bool):
	if not damage_popup_scene:
		push_warning("DamagePopupScene not set on ActorCard!")
		return

	# 1. Create the instance
	var popup = damage_popup_scene.instantiate() as Control

	# 2. Add it to the main scene tree
	battle_manager.add_child(popup)

	# 3. Calculate position - center by default
	var target_position = global_position - Vector2(100, 0)

	# Check if we spawned a popup recently
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_popup_time < POPUP_SPACING_TIME:
		# Stack them with alternating offsets
		popup_stack_offset += 1
		var side = 1 if popup_stack_offset % 2 == 0 else -1
		target_position.x += side * 60  # Offset horizontally
		target_position.y -= popup_stack_offset * 30  # Stack upward
	else:
		# Reset stack if enough time has passed
		popup_stack_offset = 0

	popup.global_position = target_position

	# 4. Update tracking
	last_popup_time = current_time

	# 5. "Fire and forget"
	popup.show_damage(amount, up, battle_manager.battle_speed, is_crit)
