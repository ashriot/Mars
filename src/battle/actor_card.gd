extends Control
class_name ActorCard

# --- Signals (Shared by both) ---
signal actor_breached(actor)
signal actor_defeated(actor)
signal actor_revived(actor)
signal hp_changed(new_hp, max_hp)
signal armor_changed(new_pips)

const MAX_GUARD = 10

var battle_manager: BattleManager

# --- Data (Shared by both) ---
var actor_name: String
var current_stats: ActorStats
var current_hp: int
var current_guard: int
var current_ct: int = 0
var is_breached: bool
var is_defeated: bool

# --- Animation Tweens ---
var shake_tween: Tween
var pulse_tween: Tween
var health_tween: Tween
var panel_home_position: Vector2

# --- UI Node References (Shared) ---
@onready var name_label: Label = $Panel/Title
@onready var hp_bar_ghost: ProgressBar = $Panel/HP/BarGhost
@onready var hp_bar_actual: ProgressBar = $Panel/HP/BarActual
@onready var hp_value: Label = $Panel/HP/Value
@onready var guard_bar: HBoxContainer = $Panel/GuardBar
@onready var portrait_rect: TextureRect = $Panel/Portrait
@onready var breached_label: Label = $BreachedLabel
@onready var panel: Panel = $Panel

func setup_base(stats: ActorStats):
	if not stats:
		push_error("ActorCard was given null stats!")
		return
	battle_manager = get_parent().get_node("%BattleManager")
	self.current_stats = stats.duplicate()
	actor_name = stats.actor_name
	hp_bar_ghost.max_value = current_stats.max_hp
	current_hp = current_stats.max_hp / 2
	hp_bar_actual.max_value = current_stats.max_hp
	hp_bar_ghost.max_value = current_stats.max_hp
	current_guard = current_stats.starting_guard
	panel_home_position = panel.position
	breached_label.hide()
	is_defeated = false
	is_breached = false
	update_health_bar()
	await get_tree().process_frame

	for pip in guard_bar.get_children():
		pip.get_child(0).set_pivot_offset(pip.size / 2.0)
	update_guard_bar()

func on_turn_started() -> void:
	await battle_manager.wait(0.1)
	# This is where all your "start of turn" buff/debuff
	# logic will go. For example:

	# for buff in active_buffs:
	#     if buff.has_start_of_turn_effect():
	#         await buff.execute_effect(self)

	# For now, it's just a tiny placeholder await
	# so the 'async' function is valid.

	if is_breached:
		recover_breach()
	return

func on_turn_ended() -> void:
	pass

func get_power(power_type: Action.PowerType) -> int:
	if power_type == Action.PowerType.ATTACK:
		return current_stats.attack
	elif power_type == Action.PowerType.PSYCHE:
		return current_stats.psyche
	return 0

func apply_one_hit(damage_effect: Effect_Damage, attacker: ActorCard, dynamic_potency: float) -> void:
	if is_defeated: return

	if damage_effect.damage_type == Action.DamageType.PIERCING:
		shake_panel()
	elif current_guard == 0:
		if not is_breached:
			is_breached = true
			current_ct = 0
			actor_breached.emit()
			shake_panel(1.0)
			_start_breach_pulse()
		else:
			shake_panel()
	else:
		current_guard -= 1
		shake_panel()

	var power_for_hit = attacker.get_power(damage_effect.power_type)
	if is_breached:
		power_for_hit += attacker.current_stats.overload

	var base_hit_damage: float = power_for_hit * dynamic_potency

	if not is_breached:
		if damage_effect.damage_type == Action.DamageType.KINETIC:
			base_hit_damage = base_hit_damage * (1.0 - current_stats.kinetic_defense)
		else: # ENERGY
			base_hit_damage = base_hit_damage * (1.0 - current_stats.energy_defense)

	var final_damage = max(0, int(base_hit_damage))
	current_hp = max(0, current_hp - final_damage)
	hp_bar_actual.value = current_hp
	hp_value.text = str(current_hp)
	hp_changed.emit(current_hp, current_stats.max_hp)

	print("Hit for ", final_damage, " damage!")
	update_guard_bar()

	# 7. Check for death
	if current_hp == 0:
		await defeated()
		return

	return

func take_healing(heal_amount: int, is_revive: bool = false):
	if (is_defeated and not is_revive) or heal_amount <= 0:
		return

	var new_hp = min(current_stats.max_hp, current_hp + heal_amount)

	current_hp = new_hp
	print(actor_name, " healed for ", heal_amount, ". HP is now: ", current_hp)
	hp_bar_ghost.value = new_hp
	hp_changed.emit(current_hp, current_stats.max_hp)

func sync_visual_health() -> Tween:
	var actual_hp = hp_bar_actual.value
	var ghost_hp = hp_bar_ghost.value

	var real_hp = current_hp

	if actual_hp == real_hp and ghost_hp == real_hp:
		return null

	var DURATION = 0.75

	if health_tween and health_tween.is_running():
		health_tween.kill()

	health_tween = create_tween()
	health_tween.set_trans(Tween.TRANS_SINE)
	health_tween.set_ease(Tween.EASE_OUT)

	if actual_hp < real_hp:
		print(actor_name, " animating heal from ", actual_hp, " to ", real_hp)

		health_tween.tween_property(hp_bar_actual, "value", real_hp, DURATION)
		health_tween.tween_method(
			func(val): hp_value.text = str(roundi(val)),
			actual_hp,
			real_hp,
			DURATION
		)

	elif ghost_hp > real_hp:
		print(actor_name, " animating damage from ", ghost_hp, " to ", real_hp)

		health_tween.tween_property(hp_bar_ghost, "value", real_hp, DURATION)

	return health_tween

func _animate_health_change(from_hp: float, to_hp: float) -> Tween:
	var DURATION = 0.75

	if health_tween and health_tween.is_running():
		health_tween.kill()

	health_tween = create_tween()
	health_tween.set_trans(Tween.TRANS_SINE)
	health_tween.set_ease(Tween.EASE_OUT)

	health_tween.tween_method(
		_update_health_display, # The function to call
		from_hp,                # Start value
		to_hp,                  # End value
		DURATION
	)

	# Wait for the tween to finish
	return health_tween

func _update_health_display(value_from_tween: float):
	hp_bar_ghost.value = value_from_tween
	hp_value.text = str(roundi(value_from_tween))

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
	gain_guard(current_stats.starting_guard)

func gain_guard(amount: int):
	if is_defeated or amount <= 0:
		return

	if current_guard == 0 and is_breached:
		is_breached = false
		_stop_breach_pulse()
		print(actor_name, " recovered from Breach!")

	current_guard = min(current_guard + amount, MAX_GUARD)

	print(actor_name, " gained ", amount, " guard. Total: ", current_guard)
	update_guard_bar()

func update_guard_bar():
	var pips = guard_bar.get_children()

	if pips.is_empty() or pips[0].size.x == 0:
		await get_tree().process_frame

	for i in pips.size():
		var pip_node = pips[i]

		if i < current_guard:

			if not pip_node.visible:
				_animate_pip(pip_node)
		else:
			pip_node.visible = false
			pip_node.scale = Vector2(1.0, 1.0)

	armor_changed.emit(current_guard)

func _start_breach_pulse():
	if not breached_label: return

	breached_label.visible = true

	# Kill old tween if it's somehow still running
	if pulse_tween:
		pulse_tween.kill()

	# Create a new tween that will loop
	pulse_tween = create_tween()
	pulse_tween.set_loops()

	# Use "self_modulate" so it doesn't affect child nodes (if you add any)
	# 1. Fade from its current color (white) to red
	pulse_tween.tween_property(
		breached_label,
		"self_modulate",
		Color.ORANGE_RED,
		0.5 # 0.5 seconds to fade to red
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 2. Fade from red back to white
	pulse_tween.tween_property(
		breached_label,
		"self_modulate",
		Color.WHITE,
		0.5 # 0.5 seconds to fade back
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_breach_pulse():
	if not breached_label: return

	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

	breached_label.visible = false
	# Reset the color to default
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

func _animate_pip(pip_node: Control):
	var pip_texture = pip_node.get_child(0)
	pip_node.show()
	# This 'await' is perfect, it ensures the node is ready
	await get_tree().process_frame

	# --- 1. Fix: Call create_tween() to get an instance ---
	var tween = create_tween()

	# --- 2. CRITICAL: Set the tween to parallel ---
	# This makes the scale and flash happen simultaneously.
	tween.set_parallel()

	# You can set different transitions for each property,
	# but we'll set a default for the "pop"
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)

	pip_texture.scale = Vector2(2.0, 2.0)
	pip_texture.modulate = Color(5.0, 5.0, 5.0)

	tween.tween_property(
		pip_texture,
		"scale",
		Vector2(1.0, 1.0),
		0.75 # Your "pop" duration
	)

	tween.tween_property(
		pip_texture,
		"modulate",
		Color(1.0, 1.0, 1.0), # The normal Color.WHITE
		0.25 # A much faster duration
	).set_trans(Tween.TRANS_SINE) # Use a smooth fade for the color

func _on_gui_input(_event: InputEvent):
	pass
