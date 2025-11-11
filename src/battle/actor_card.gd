extends Control
class_name ActorCard

# --- Signals (Shared by both) ---
signal actor_breached(actor)
signal actor_defeated(actor)
signal actor_revived(actor)
signal hp_changed(new_hp, max_hp)
signal armor_changed(new_pips)

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
var panel_home_position: Vector2

# --- UI Node References (Shared) ---
@onready var name_label: Label = $Panel/Title
@onready var hp_bar: ProgressBar = $Panel/HP/Bar
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
	hp_bar.max_value = current_stats.max_hp
	current_hp = current_stats.max_hp
	hp_bar.value = current_hp
	current_guard = current_stats.starting_guard
	panel_home_position = panel.position
	breached_label.hide()
	is_defeated = false
	is_breached = false
	update_health_bar()
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

func take_damage_from_action(action: Action, attacker: ActorCard) -> void:
	print("\n--- Executing action: ", action.action_name, " for ", action.hit_count, " hit(s) ---")

	for i in action.hit_count:
		if is_defeated: return

		if action.damage_type == Action.DamageType.PIERCING:
			shake_panel()
		elif current_guard == 0:
			if not is_breached:
				is_breached = true
				current_ct = 0
				actor_breached.emit()
				shake_panel(1.0)
				_start_breach_pulse()
		else:
			current_guard -= 1
			shake_panel()

		var power_for_hit = attacker.get_power(action.power_type)
		if is_breached:
			power_for_hit += attacker.current_stats.overload
		var dynamic_potency = action.get_dynamic_potency(attacker, self)
		var base_hit_damage = int(power_for_hit * dynamic_potency)
		var final_damage = base_hit_damage # PIERCING DAMAGE

		if not is_breached:
			if action.damage_type == Action.DamageType.KINETIC:
				final_damage = base_hit_damage * (1.0 - current_stats.kinetic_defense)
			else: # ENERGY
				final_damage = base_hit_damage * (1.0 - current_stats.energy_defense)

		final_damage = max(0, int(final_damage))
		current_hp = max(0, current_hp - final_damage)
		print("Hit ", i+1, ": ", final_damage, " damage!")

		update_health_bar()
		update_guard_bar()

		# 7. Check for death
		if current_hp == 0:
			await defeated()
			return

		if action.hit_count > 1 and i < action.hit_count - 1:
				await battle_manager.wait(0.25)
	return

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

func take_healing(heal_amount: int, is_revive: bool = false):
	if (is_defeated and not is_revive) or heal_amount <= 0:
		return

	current_hp = min(current_stats.max_hp, current_hp + heal_amount)
	print(name, " healed for ", heal_amount, ". HP is now: ", current_hp)
	update_health_bar()

func recover_breach():
	is_breached = false
	current_guard = current_stats.starting_guard
	_stop_breach_pulse()
	update_guard_bar()

func update_health_bar():
	hp_bar.value = current_hp
	hp_value.text = str(current_hp)
	hp_changed.emit(current_hp, current_stats.max_hp)

func update_guard_bar():
	var pips = guard_bar.get_children()
	for i in pips.size():
		if i < current_guard:
			pips[i].visible = true
		else:
			pips[i].visible = false
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
	print("Shaking ", actor_name, "'s Panel!")

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
