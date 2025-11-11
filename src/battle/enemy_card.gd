extends ActorCard
class_name EnemyCard

# --- UNIQUE Signals ---
signal enemy_clicked(enemy_card)

# --- UNIQUE Data ---
var enemy_data: EnemyData
var ai_index: int = 0
var intended_action: Action
var intended_target: ActorCard

# --- UNIQUE UI Node References ---
@onready var intent_icon: TextureRect = $Panel/IntentIcon
@onready var intent_effect: Label = $Panel/IntentEffect
@onready var defenses: Label = $Panel/Defenses


func setup(data: EnemyData):
	self.enemy_data = data
	# --- Call the PARENT's setup function ---
	setup_base(data.stats)

	name_label.text = enemy_data.stats.actor_name
	$Panel/Defenses.text = "KIN: " + str(int(enemy_data.stats.kinetic_defense * 100)) \
	+ "%       NRG: " + str(int(enemy_data.stats.energy_defense * 100)) + "%"
	if enemy_data.portrait:
		portrait_rect.texture = enemy_data.portrait

	add_to_group("enemy")

func get_next_action() -> Action:
	if enemy_data.action_deck.is_empty():
		push_error(enemy_data.enemy_name + " has no actions in its action_deck!")
		return null

	# Just grab the first action every time for testing.
	var next_action = enemy_data.action_deck[0]
	return next_action
	if enemy_data.ai_script_indices.is_empty():
		return null

	var script = enemy_data.ai_script_indices
	var ability_index = script[ai_index]
	next_action = enemy_data.action_deck[ability_index]

	ai_index = (ai_index + 1) % script.size()
	return next_action

func decide_intent(hero_targets: Array):
	self.intended_action = get_next_action()
	self.intended_target = null

	match intended_action.target_type:
		Action.TargetType.ONE_ENEMY:
			# This is your "random target" logic
			if not hero_targets.is_empty():
				self.intended_target = hero_targets.pick_random()

		Action.TargetType.SELF:
			self.intended_target = self # Target itself

		# For these, no specific target is needed
		Action.TargetType.ALL_ENEMIES:
			pass

	update_intent_ui()

func update_intent_ui():
	if not intended_action:
		intent_effect.text = ""
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

		if intended_target:
			# Your 'actor_name' fix now works
			final_text += " > " + intended_target.actor_name

		intent_effect.text = final_text

	else:
		# --- 4. It's a non-damage effect (like Grant Guard) ---
		# Just show the action's name and target
		var final_text = intended_action.action_name
		if intended_target:
			final_text += " > " + intended_target.actor_name

		intent_effect.text = final_text

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
	self.modulate.a = 0

func show_intent(icon: Texture):
	intent_icon.texture = icon
	intent_icon.visible = true

func hide_intent():
	intent_icon.visible = false

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		enemy_clicked.emit(self)
		get_viewport().set_input_as_handled()
