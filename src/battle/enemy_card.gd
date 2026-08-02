extends ActorCard
class_name EnemyCard

# --- UNIQUE Signals ---
signal enemy_clicked(enemy_card)

# --- UNIQUE UI Node References ---
@onready var intent_text: RichTextLabel = $Panel/IntentText
@onready var intent_tooltip: RichTooltip = $Panel/IntentText/RichTooltip
@onready var kin_def_gauge: TextureProgressBar = $Panel/KinDef
@onready var kin_def_value: Label = $Panel/KinDef/Value
@onready var nrg_def_gauge: TextureProgressBar = $Panel/NrgDef
@onready var nrg_def_value: Label = $Panel/NrgDef/Value

var intent_flash_tween: Tween

func setup_from_combatant(model: EnemyCombatant) -> void:
	_ensure_battle_manager()
	bind_combatant(model)
	model.presentation_event.connect(_on_enemy_presentation_event)
	await _setup_card_visuals()
	_render_enemy_state()


func _render_enemy_state() -> void:
	var model := combatant as EnemyCombatant
	$Panel/Info/Text.text = "Rk. " + str(model.enemy_data.level)
	if model.is_elite:
		$Panel/Info/Text.text += " ELITE"
		name_label.modulate = Color.ORANGE_RED
	elif model.is_boss:
		$Panel/Info/Text.text += " BOSS"
		name_label.modulate = Color.MAGENTA
	update_defenses()
	name_label.text = model.enemy_data.stats.actor_name
	if model.enemy_data.portrait:
		portrait_rect.texture = model.enemy_data.portrait


func _on_enemy_presentation_event(
	_enemy: BattleCombatant,
	event: StringName,
	payload: Dictionary,
) -> void:
	if event != &"intent_changed":
		return
	_update_intent_ui()
	if bool(payload.get("changed", false)):
		flash_intent()

func refresh_intent_presentation() -> void:
	_update_intent_ui()


func _update_intent_ui():
	var model := combatant as EnemyCombatant
	if not model.intended_action:
		intent_text.text = ""
		return

	if model.intended_action.effects.is_empty():
		return

	var first_effect = model.intended_action.effects[0]
	var enemy_model := combatant as EnemyCombatant
	var presentation_targets: Array[BattleCombatant] = []
	presentation_targets.assign(model.intended_targets)

	if first_effect is Effect_Damage:
		var damage_effect: Effect_Damage = first_effect
		var resolved_hit_count := damage_effect._resolve_hit_count(enemy_model)
		var sequence := DamagePreview.for_plan(
			damage_effect,
			enemy_model,
			presentation_targets,
			model.intended_action,
			false,
			battle_manager,
		)
		var damage_bindings: Dictionary
		if sequence.is_complete and not sequence.results.is_empty():
			damage_bindings = damage_effect._get_sequence_bindings(sequence, 28)
		else:
			var context := EffectPresentationContext.new(
				enemy_model, null, model.intended_action,
			)
			damage_bindings = damage_effect.get_presentation(context).bindings
			damage_bindings.damage_type = damage_effect._get_damage_type_icon(
				damage_effect.damage_type, 28,
			)
		var final_text := "%s%s%s %s" % [
			damage_bindings.amount,
			damage_bindings.amount_qualifier,
			damage_bindings.hit_count_text,
			damage_bindings.damage_type,
		]
		if model.intended_action.target_type == Action.TargetType.RANDOM_ENEMY \
			and resolved_hit_count > 1 \
			and damage_bindings.hit_count_text.is_empty():
			final_text += " (%d hits)" % resolved_hit_count
		if model.intended_action.effects.size() > 1:
			final_text += " *"

		if model.intended_targets:
			if model.intended_targets.size() > 1:
				if model.intended_action.target_type == Action.TargetType.RANDOM_ENEMY:
					final_text += " RANDOM"
				else:
					final_text += " EVERYONE"
			else:
				var tar := model.intended_targets[0] as HeroCombatant
				var col := tar.get_current_role().color.to_html()
				final_text += " [color=" + col + "]" + model.intended_targets[0].actor_name

		intent_text.text = final_text

	else:
		var final_text = model.intended_action.action_name
		if model.intended_targets.size() > 1:
			final_text += " EVERYONE"
		elif model.intended_targets.size() == 1:
			if model.intended_targets[0].actor_name != model.actor_name:
				final_text += " " + model.intended_targets[0].actor_name

		intent_text.text = final_text
	var tooltip_target: BattleCombatant = presentation_targets[0] \
		if model.intended_targets.size() == 1 else null
	intent_tooltip.bbcode_text = model.intended_action.get_rich_description(
		combatant, tooltip_target, presentation_targets, battle_manager,
	)

func update_defenses():
	var model := combatant as EnemyCombatant
	var kin_def = model.enemy_data.stats.kinetic_defense
	var nrg_def = model.enemy_data.stats.energy_defense
	kin_def_value.text = str(kin_def) + "%"
	nrg_def_value.text = str(nrg_def) + "%"
	kin_def_gauge.value = kin_def
	nrg_def_gauge.value = nrg_def

func _show_defeated_visual(immediate: bool = false) -> void:
	if immediate:
		modulate.a = 0
		return
	var tween = create_tween()
	tween.tween_property(
		self,
		"modulate:a", # Animate the alpha
		0.0,          # To fully transparent
		0.25          # Over 0.25 seconds
	).set_trans(Tween.TRANS_SINE)

	await tween.finished
	modulate.a = 0

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
		print("Clicked on: ", _require_combatant().actor_name)
		enemy_clicked.emit(self)
		get_viewport().set_input_as_handled()
