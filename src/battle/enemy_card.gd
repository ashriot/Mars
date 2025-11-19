extends ActorCard
class_name EnemyCard

# --- UNIQUE Signals ---
signal enemy_clicked(enemy_card)

# --- UNIQUE Data ---
var enemy_data: EnemyData
var ai_index: int = 0
var intended_action: Action
var intended_targets: Array[ActorCard]
var intent_flash_tween: Tween

# --- UNIQUE UI Node References ---
@onready var intent_text: Label = $Panel/IntentText
@onready var kin_def_gauge: TextureProgressBar = $Panel/KinDef
@onready var kin_def_value: Label = $Panel/KinDef/Value
@onready var nrg_def_gauge: TextureProgressBar = $Panel/NrgDef
@onready var nrg_def_value: Label = $Panel/NrgDef/Value


func setup(data: EnemyData):
	enemy_data = data
	enemy_data.calculate_stats()
	setup_base(enemy_data.stats)
	update_defenses()

	name_label.text = enemy_data.stats.actor_name
	if enemy_data.portrait:
		portrait_rect.texture = enemy_data.portrait

func get_next_action() -> Action:
	if enemy_data.action_deck.is_empty():
		push_error(enemy_data.enemy_name + " has no actions in its action_deck!")
		return null

	var next_action = enemy_data.action_deck.pick_random()
	return next_action
	#if enemy_data.ai_script_indices.is_empty():
		#return null
#
	#var script = enemy_data.ai_script_indices
	#var ability_index = script[ai_index]
	#next_action = enemy_data.action_deck[ability_index]
#
	#ai_index = (ai_index + 1) % script.size()
	#return next_action

func decide_intent(hero_targets: Array[HeroCard]):
	intended_action = get_next_action()
	get_a_target(hero_targets)

func get_a_target(hero_targets: Array[HeroCard]):
	var enemy_targets = battle_manager.get_living_enemies() as Array[EnemyCard]
	var new_targets: Array[ActorCard] = []

	if not intended_action or hero_targets.is_empty():
		update_intent_ui()
		return

	match intended_action.target_type:
		Action.TargetType.ONE_ENEMY:
			if hero_targets.is_empty():
				return
			var taunting_hero = null
			for hero in hero_targets:
				if hero.has_condition("Draw Fire"):
					taunting_hero = hero
					break
			if taunting_hero:
				new_targets = [taunting_hero]
			else:
				new_targets = [hero_targets.pick_random()]

		Action.TargetType.SELF:
			new_targets = [self]
		Action.TargetType.ALL_ENEMIES, Action.TargetType.RANDOM_ENEMY:
			for target in hero_targets:
				new_targets.append(target)
		Action.TargetType.LEAST_GUARD_ALLY:
			var final_target = enemy_targets[0]
			for target in enemy_targets:
				if target.current_guard < final_target.current_guard:
					final_target = target
			new_targets = [final_target]

	if new_targets != intended_targets:
		intended_targets = new_targets
		update_intent_ui()

func update_intent_ui():
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
					final_text += " > RANDOM"
				else:
					final_text += " > EVERYONE"
			else:
				final_text += " > " + intended_targets[0].actor_name

		intent_text.text = final_text

	else:
		var final_text = intended_action.action_name
		if intended_targets.size() > 1:
			final_text += " > EVERYONE"
		else:
			final_text += " > " + intended_targets[0].actor_name

		intent_text.text = final_text
	flash_intent()

func breach():
	super.breach()
	update_defenses()

func recover_breach():
	super.recover_breach()
	update_defenses()

func update_defenses():
	var kin_def = enemy_data.stats.kinetic_defense
	var nrg_def = enemy_data.stats.energy_defense
	if is_breached:
		kin_def /= 2
		nrg_def /= 2
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
