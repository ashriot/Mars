extends Control
class_name ActorCard

@export var damage_popup_scene: PackedScene
@export var buff_scene: PackedScene
@export var debuff_scene: PackedScene

# --- Signals (Shared by both) ---
signal actor_breached(actor)
signal actor_defeated(actor)
signal actor_revived(actor)
signal hp_changed(new_hp, max_hp)
signal armor_changed(new_pips)
signal actor_conditions_changed(actor, retarget)
signal spawn_particles(pos, type)

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
var is_in_danger: bool
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
@onready var guard_label: Label = $Panel/GuardValue
@onready var portrait_rect: TextureRect = $Panel/Portrait
@onready var breached_label: Label = $Panel/BreachedLabel
@onready var highlight_panel: Panel = $Panel/Highlight
@onready var target_flash: Panel = $Panel/TargetFlash
@onready var action_display: PanelContainer = $Panel/ActionName
@onready var next_panel: Panel = $Panel/NextPanel
@onready var debuffs_panel: Control = $Panel/Debuffs
@onready var buffs_panel: Control = $Panel/Buffs


func setup_base(stats: ActorStats):
	if not stats:
		push_error("ActorCard was given null stats!")
		return
	battle_manager = get_parent().get_node("%BattleManager")
	current_stats = stats
	actor_name = stats.actor_name
	hp_bar_ghost.max_value = current_stats.max_hp
	current_hp = current_stats.max_hp
	hp_bar_actual.max_value = current_stats.max_hp
	hp_bar_ghost.max_value = current_stats.max_hp
	current_guard = current_stats.starting_guard
	panel_home_position = panel.position
	breached_label.hide()
	is_defeated = false
	is_breached = false
	highlight_panel.hide()
	target_flash.hide()
	target_flash.modulate.a = 0.2
	hp_bar_ghost.hide()
	update_health_bar()
	hp_bar_actual.value = 0
	action_display.hide()
	next_panel.hide()
	await get_tree().process_frame

	for pip in guard_bar.get_children():
		pip.get_child(0).set_pivot_offset(pip.size / 2.0)
	update_guard_bar(false)

func on_turn_started() -> void:
	next_panel.hide()
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

func take_one_hit(damage: int, damage_effect: Effect_Damage, attacker: ActorCard, damage_type: Action.DamageType, is_crit: bool) -> void:
	if is_defeated: return

	_spawn_damage_popup(damage, damage_type, is_crit)
	var pos = get_global_rect().get_center()
	spawn_particles.emit(pos, "gunshot")
	current_hp = max(0, current_hp - damage)
	hp_bar_actual.value = current_hp
	hp_value.text = str(current_hp)
	hp_changed.emit(current_hp, current_stats.max_hp)
	print("Hit for ", damage, " damage!")
	update_guard_bar()

	if current_hp == 0:
		await defeated()
		return
	var context = { "attacker": attacker, "targets": [self] }
	if damage_effect.damage_type == Action.DamageType.KINETIC:
		await _fire_condition_event(Trigger.TriggerType.ON_TAKING_KINETIC_DAMAGE, context)
	elif damage_effect.damage_type == Action.DamageType.ENERGY:
		await _fire_condition_event(Trigger.TriggerType.ON_TAKING_ENERGY_DAMAGE, context)
	if not damage_effect.is_indirect:
		context = { "attacker": attacker, "damage_dealt": damage }
		await _fire_condition_event(Trigger.TriggerType.ON_BEING_HIT, context)

	if current_hp == 0:
		await defeated()

func in_danger(value: bool):
	is_in_danger = value
	breached_label.text = "VULNERABLE"
	if value:
		_start_breach_pulse()
	else:
		_stop_breach_pulse()

func breach():
	is_breached = true
	is_in_danger = false
	breached_label.text = "BREACHED"
	guard_bar.modulate.a = 0.5
	current_ct = 0
	print("Breached: ", actor_name, " -> CT: ", current_ct)
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

	var _is_buff = condition_resource.condition_type == Condition.ConditionType.BUFF
	var is_debuff = condition_resource.condition_type == Condition.ConditionType.DEBUFF
	for active_cond in active_conditions:
			for trigger in active_cond.triggers:
				if trigger.trigger_type == Trigger.TriggerType.BEFORE_DEBUFF_RECEIVED and is_debuff:
					print("Condition '", active_cond.condition_name, "' is blocking the new condition: ", condition_resource.condition_name)
					for effect in trigger.effects_to_run:
						await battle_manager.execute_triggered_effect(self, effect, [self], null, {})
					return

	if has_condition(condition_resource.condition_name):
		return
	var new_condition = condition_resource.duplicate(true)
	new_condition.attacker = condition_resource.attacker
	active_conditions.append(new_condition)
	print(actor_name, " gained condition: ", new_condition.condition_name)

	await _fire_condition_event(Trigger.TriggerType.ON_APPLIED)
	actor_conditions_changed.emit(self, new_condition.retarget)
	_update_conditions_ui()

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
			_update_conditions_ui()
			return

	push_error("[ERROR] Trying to remove an invalid condition: ", actor_name, " -> ", condition_name)
	return

func remove_debuffs(quantity: int):
	var amount_removed = 0
	if active_conditions.is_empty(): return
	for i in range(active_conditions.size() - 1, -1, -1):
		var condition = active_conditions[i]
		if condition.condition_type == Condition.ConditionType.DEBUFF:
			amount_removed += 1
			active_conditions.erase(condition)
			print(actor_name, " is removing condition: ", condition.condition_name)
			_update_conditions_ui()
			if amount_removed == quantity:
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
	hp_value.text = str(roundi(value_from_tween))

func _fire_condition_event(event_type: Trigger.TriggerType, context: Dictionary = {}) -> void:
	for i in range(active_conditions.size() - 1, -1, -1):
		var condition = active_conditions[i] as Condition
		var is_attack = false
		if condition.remove_on_triggers.has(event_type):
			print(actor_name, "'s ", condition.condition_name, " needs to be removed.")
			await _fire_condition_event(Trigger.TriggerType.ON_REMOVED)
			remove_condition(condition.condition_name)
		for trigger in condition.triggers:
			trigger = trigger as Trigger
			if trigger.trigger_type != event_type: continue
			if trigger.is_attack:
				is_attack = true
				await battle_manager.wait(0.25)
			print("Condition '", condition.condition_name, "' is firing effects for '", event_type, "'")
			var targets = []
			var attacker = null
			var source = condition.attacker
			var action = context.get("action")
			if context.has("targets"):
				targets = context.targets
			if context.has("attacker"):
				attacker = context.attacker
			for effect in trigger.effects_to_run:
				var is_hero = self is HeroCard
				effect = effect as ActionEffect
				targets = battle_manager.get_targets(effect.target_type, is_hero, targets, attacker)
				if battle_manager.current_actor is HeroCard and condition.is_passive and trigger.trigger_type == Trigger.TriggerType.ON_TURN_START:
					self.passive_fired.emit()
				await battle_manager.execute_triggered_effect(source, effect, targets, action, context)
				if condition.update_turn_order:
					battle_manager.update_turn_order()

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
	await modify_guard(current_stats.starting_guard, true)

func modify_guard(amount: int, is_recovering: bool = false):
	current_guard = clamp(current_guard + amount, 0, MAX_GUARD)

	print(actor_name, " gained ", amount, " guard. Total: ", current_guard)
	var context = { "targets": [self], "guard_gained": amount}
	if amount > 0 and not is_recovering:
		await _fire_condition_event(Trigger.TriggerType.ON_GAINING_GUARD, context)
	if current_guard == 0 and not is_breached:
		in_danger(true)
	elif is_in_danger:
		in_danger(false)

	update_guard_bar()

func is_taunting() -> bool:
	for c in active_conditions:
		if c.is_taunting:
			return true
	return false

func is_untargetable() -> bool:
	for c in active_conditions:
		if c.is_untargetable:
			return true
	return false

func update_guard_bar(animate: bool = true):
	guard_label.text = str(current_guard)
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
	if power_type == Action.PowerType.ATTACK:
		print(actor_name, "'s ATK is: ", current_stats.attack)
		return current_stats.attack
	elif power_type == Action.PowerType.PSYCHE:
		print(actor_name, "'s PSY is: ", current_stats.psyche)
		return current_stats.psyche
	return 0

func get_speed() -> int:
	var scalar: float = 1.0
	for condition in active_conditions:
		scalar += condition.speed_scalar
	return int(current_stats.speed * scalar)

func get_aim() -> int:
	var mod: int = 0
	for condition in active_conditions:
		mod += condition.aim_mod
	return current_stats.aim + mod

func get_incoming_aim_mods() -> int:
	var mod: int = 0
	for condition in active_conditions:
		mod += condition.incoming_aim_mod
	return mod

func get_crit_damage_bonus() -> float:
	return 0.5

func get_damage_dealt_scalar(target: ActorCard) -> float:
	var scalar: float = 1.0
	for condition in active_conditions:
		scalar += condition.get_damage_dealt_scalar(self, target)
	return scalar

func get_damage_taken_scalar() -> float:
	var scalar: float = 1.0
	for condition in active_conditions:
		scalar += condition.damage_taken_scalar
	return scalar

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
