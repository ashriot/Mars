extends ActorCard
class_name EnemyCard

# --- UNIQUE Signals ---
signal enemy_clicked(enemy_card)

# --- UNIQUE UI Node References ---
@onready var intent_text: RichTextLabel = $Panel/IntentText
@onready var kin_def_gauge: TextureProgressBar = $Panel/KinDef
@onready var kin_def_value: Label = $Panel/KinDef/Value
@onready var nrg_def_gauge: TextureProgressBar = $Panel/NrgDef
@onready var nrg_def_value: Label = $Panel/NrgDef/Value

# --- UNIQUE Data ---
var enemy_data: EnemyData
var ai_index: int = 0
var intended_action: Action
var base_turn_action: Action
var intended_targets: Array[ActorCard]
var intent_flash_tween: Tween
var used_overrides: Array[AIOverride] = []
var turn_counter: int = 0


func setup(data: EnemyData, fight_level: int):
	enemy_data = data
	enemy_data.level = fight_level
	$Panel/Level.text = "Rk. " + str(data.level)
	enemy_data.calculate_stats()
	setup_base(enemy_data.stats)
	update_defenses()

	name_label.text = enemy_data.stats.actor_name
	if enemy_data.portrait:
		portrait_rect.texture = enemy_data.portrait

func prepare_turn_base_action():
	turn_counter += 1

	if enemy_data.action_deck.is_empty():
		base_turn_action = null
		return

	# Advance the sequence/RNG exactly once per turn
	if enemy_data.ai_pattern == EnemyData.AIPattern.RANDOM:
		base_turn_action = enemy_data.action_deck.pick_random()
	else:
		# SEQUENCE
		var script = enemy_data.ai_script_indices
		if script.is_empty():
			var i = turn_counter % enemy_data.action_deck.size() - 1
			base_turn_action = enemy_data.action_deck[i]
		else:
			var ability_index = script[ai_index]
			base_turn_action = enemy_data.action_deck[ability_index]
			ai_index = (ai_index + 1) % script.size()

func decide_intent(hero_targets: Array[HeroCard]):
	var new_proposed_action: Action = null
	var override_action = _check_ai_overrides()

	if override_action:
		new_proposed_action = override_action
	else:
		new_proposed_action = base_turn_action

	if new_proposed_action == intended_action:
		if _is_current_target_valid(hero_targets):
			return

	# 3. CHANGE PLAN
	# Either the action changed, OR the old target died/hid.
	self.intended_action = new_proposed_action
	get_a_target(hero_targets) # Pick a fresh target based on the new action

func _is_current_target_valid(hero_targets: Array[HeroCard]) -> bool:
	# 1. Do we have a target?
	if intended_targets.is_empty() or not intended_targets[0]:
		return false

	var current = intended_targets[0]

	# 2. Is it alive?
	if not is_instance_valid(current) or current.is_defeated:
		return false

	# 3. Check Faction Rules
	if current.is_in_group("player"):
		# A. Did they Stealth? (Decoy)
		if current.is_untargetable():
			return false

		if not current.is_taunting():
			for h in hero_targets:
				if h.is_taunting():
					return false
	return true

func get_a_target(hero_targets: Array[HeroCard]):
	if not intended_action:
		_update_intent_ui()
		return

	var my_allies = battle_manager.get_living_enemies()
	var new_targets: Array[ActorCard] = []

	match intended_action.target_type:
		# --- OFFENSIVE TARGETING (Against Heroes) ---
		Action.TargetType.ONE_ENEMY:
			# 1. Filter Untargetable (Decoy)
			var valid_heroes = []
			for hero in hero_targets:
				if not hero.is_untargetable():
					valid_heroes.append(hero)

			# Safety: If everyone is hidden, target anyone
			if valid_heroes.is_empty(): valid_heroes = hero_targets

			# 2. Filter Taunts (Draw Fire)
			var taunting_heroes = []
			for hero in valid_heroes:
				if hero.is_taunting():
					taunting_heroes.append(hero)

			if not taunting_heroes.is_empty():
				new_targets = [taunting_heroes.pick_random()]
			else:
				new_targets = [valid_heroes.pick_random()]

		Action.TargetType.ALL_ENEMIES, Action.TargetType.RANDOM_ENEMY:
			# For an Enemy, "All Enemies" means "All Heroes"
			for h in hero_targets:
				new_targets.append(h)

		# --- DEFENSIVE TARGETING (Against Self/Allies) ---
		Action.TargetType.SELF:
			new_targets = [self]

		Action.TargetType.ONE_ALLY:
			# Target a random ally (could be self)
			if not my_allies.is_empty():
				new_targets = [my_allies.pick_random()]

		Action.TargetType.ALLIES_ONLY:
			# Target ally excluding self
			var friends = []
			for ally in my_allies:
				if ally != self: friends.append(ally)

			if not friends.is_empty():
				new_targets = [friends.pick_random()]
			else:
				new_targets = [self] # Fallback to self if alone

		Action.TargetType.LEAST_GUARD_ALLY:
			# Your existing logic
			var final_target = my_allies[0]
			for ally in my_allies:
				if ally.current_guard < final_target.current_guard:
					final_target = ally
			new_targets = [final_target]

		# (Add WEAKEST_ALLY, etc. here as needed)

	# Only update UI if something actually changed
	if new_targets != intended_targets:
		intended_targets = new_targets
		_update_intent_ui()

func _check_ai_overrides() -> Action:
	if enemy_data.ai_overrides.is_empty(): return null

	for override in enemy_data.ai_overrides:
		if override.one_time_use and override in used_overrides: continue

		var condition_met = false

		match override.priority:
			AIOverride.PriorityType.FIRST_TURN:
				condition_met = (turn_counter == 1)

			AIOverride.PriorityType.HEALTH_BELOW_50:
				var percent = float(current_hp) / float(current_stats.max_hp)
				condition_met = (percent <= 0.50)

			AIOverride.PriorityType.HEALTH_BELOW_25:
				var percent = float(current_hp) / float(current_stats.max_hp)
				condition_met = (percent <= 0.25)

			AIOverride.PriorityType.WHEN_SELF_BREACHED:
				condition_met = is_breached

			AIOverride.PriorityType.HAS_BUFF:
				if override.context_value != "":
					condition_met = has_condition(override.context_value)
				else:
					condition_met = not active_conditions.is_empty()

			AIOverride.PriorityType.WHEN_ALLY_BREACHED:
				var allies = battle_manager.get_living_enemies()
				for ally in allies:
					if ally != self and ally.is_breached:
						condition_met = true
						break

			AIOverride.PriorityType.WHEN_PLAYER_BREACHED:
				var heroes = battle_manager.get_living_heroes()
				for hero in heroes:
					if hero.is_breached:
						condition_met = true
						break

			AIOverride.PriorityType.ALLY_HP_LOW:
				var allies = battle_manager.get_living_enemies()
				for ally in allies:
					if ally == self: continue
					var pct = float(ally.current_hp) / float(ally.current_stats.max_hp)
					if pct < 0.5: # Threshold for "Low"
						condition_met = true
						break

		if condition_met:
			if randf() <= override.probability:
				if override.one_time_use:
					used_overrides.append(override)
				return override.action_to_use

	return null

func _update_intent_ui():
	if not intended_action:
		intent_text.text = ""
		return

	if intended_action.effects.is_empty():
		return

	var first_effect = intended_action.effects[0]

	if first_effect is Effect_Damage:
		# We cast it to access its unique properties
		var damage_effect: Effect_Damage = first_effect

		# --- 3. Now your code will work ---
		var power = get_power(damage_effect.power_type)

		var intended_dmg = int(power * damage_effect.potency)
		if damage_effect.split_damage:
			intended_dmg /= 3

		var dmg_type = ""
		match damage_effect.damage_type:
			Action.DamageType.KINETIC:
				dmg_type = "KIN"
			Action.DamageType.ENERGY:
				dmg_type = "NRG"
			Action.DamageType.PIERCING:
				dmg_type = "PRC"

		var hits_text = "x" + str(damage_effect.hit_count) if damage_effect.hit_count > 1 else ""

		# This is your final text string
		var final_text = str(intended_dmg) + hits_text + " " + dmg_type

		if intended_targets:
			if intended_targets.size() > 1:
				if intended_action.target_type == Action.TargetType.RANDOM_ENEMY:
					final_text += ">RANDOM"
				else:
					final_text += ">EVERYONE"
			else:
				final_text += "> " + intended_targets[0].actor_name

		intent_text.text = final_text

	else:
		var final_text = intended_action.action_name
		if intended_targets.size() > 1:
			final_text += " -> EVERYONE"
		else:
			final_text += " -> " + intended_targets[0].actor_name

		intent_text.text = final_text
	flash_intent()

func clear_intent():
	intended_action = null
	intended_targets = []
	_update_intent_ui()

func breach():
	super.breach()
	update_defenses()

func recover_breach():
	super.recover_breach()
	update_defenses()

func update_defenses():
	var kin_def = enemy_data.stats.kinetic_defense
	var nrg_def = enemy_data.stats.energy_defense
	kin_def_value.text = str(kin_def) + "%"
	nrg_def_value.text = str(nrg_def) + "%"
	kin_def_gauge.value = kin_def
	nrg_def_gauge.value = nrg_def

func defeated():
	super.defeated()
	var tween = create_tween()
	tween.tween_property(
		self,
		"modulate:a", # Animate the alpha
		0.0,          # To fully transparent
		0.25          # Over 0.25 seconds
	).set_trans(Tween.TRANS_SINE)

	await tween.finished
	modulate.a = 0

#func show_intent(icon: Texture):
	#intent_icon.texture = icon
	#intent_icon.visible = true
#
#func hide_intent():
	#intent_icon.visible = false

func flash_intent(duration: float = 0.3):
	duration /= battle_manager.battle_speed

	if intent_flash_tween and intent_flash_tween.is_running():
		intent_flash_tween.kill()

	var flash_color = Color.ORANGE_RED
	var base_color = Color(1.0, 1.0, 1.0)

	intent_flash_tween = create_tween()

	intent_flash_tween.tween_property(intent_text, "modulate",
		flash_color, duration).set_trans(Tween.TRANS_SINE)
	intent_flash_tween.tween_property(intent_text, "modulate",
		base_color, duration).set_trans(Tween.TRANS_SINE)

	await intent_flash_tween.finished

func _on_gui_input(event: InputEvent):
	if event.is_action_pressed("ui_accept"):
		print("Clicked on: ", actor_name)
		enemy_clicked.emit(self)
		get_viewport().set_input_as_handled()
