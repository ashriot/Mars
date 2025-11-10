extends Control
class_name ActorCard

# --- Signals (Shared by both) ---
signal i_was_breached
signal i_am_dead
signal hp_changed(new_hp, max_hp)
signal armor_changed(new_pips)

# --- Data (Shared by both) ---
var actor_name: String
var current_stats: ActorStats
var current_hp: int
var current_guard: int
var current_ct: int = 0
var is_breached:
	get: return current_guard == 0

# --- UI Node References (Shared) ---
@onready var hp_bar: ProgressBar = $Panel/HP/Bar
@onready var hp_value: Label = $Panel/HP/Value
@onready var guard_bar: HBoxContainer = $Panel/GuardBar
@onready var portrait_rect: TextureRect = $Panel/Portrait

func setup_base(stats: ActorStats):
	if not stats:
		push_error("ActorCard was given null stats!")
		return
	self.current_stats = stats.duplicate()
	actor_name = stats.actor_name
	hp_bar.max_value = current_stats.max_hp
	current_hp = current_stats.max_hp
	hp_bar.value = current_hp
	current_guard = current_stats.starting_guard
	update_health_bar()
	update_guard_bar()

func on_turn_started() -> void:
	# This is where all your "start of turn" buff/debuff
	# logic will go. For example:

	# for buff in active_buffs:
	#     if buff.has_start_of_turn_effect():
	#         await buff.execute_effect(self)

	# For now, it's just a tiny placeholder await
	# so the 'async' function is valid.
	await get_tree().create_timer(0.01).timeout
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
	var attacker_stats = attacker.current_stats

	# 1. Get the base power for this action
	var base_power = attacker.get_power(action.power_type)

	print("\n--- Executing action: ", action.action_name, " for ", action.hit_count, " hit(s) ---")

	# 2. Loop for each hit
	for i in action.hit_count:
		var final_damage = 0

		if current_guard > 0:
			current_guard -= 1
			if current_guard == 0:
				current_ct = 0
				i_was_breached.emit()

		# 4. Calculate damage for *this* hit
		if action.damage_type == Action.DamageType.PIERCING:
			# Piercing logic
			if is_breached:
				# Use new Overload formula
				final_damage = int((base_power + attacker_stats.overload) * action.potency)
			else:
				final_damage = int(base_power * action.potency)
			# (Piercing does NOT shred pips)

		else: # Kinetic or Energy
			if is_breached:
				final_damage = int((base_power + attacker_stats.overload) * action.potency)
			else:
				# --- It's an Armored hit ---
				var damage_before_defense = int(base_power * action.potency)
				if action.damage_type == Action.DamageType.KINETIC:
					final_damage = int(damage_before_defense * (1.0 - current_stats.kinetic_defense))
				else: # ENERGY
					final_damage = int(damage_before_defense * (1.0 - current_stats.energy_defense))

		final_damage = max(0, final_damage)
		current_hp = max(0, current_hp - final_damage)

		print("Hit ", i+1, ": ", final_damage, " damage!")

		# 6. Update UI
		update_health_bar()
		update_guard_bar()

		# 7. Check for death
		if current_hp == 0:
			i_am_dead.emit()
			return
		if action.hit_count > 1 and i < action.hit_count - 1:
			await get_tree().create_timer(0.25).timeout
	print("\n")
	return

func recover_breach():
	current_guard = current_stats.starting_guard
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
