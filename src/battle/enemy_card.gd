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
	if not bind_combatant(model):
		return
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


func _update_intent_ui() -> void:
	var model := combatant as EnemyCombatant
	var formatted := EnemyIntentFormatter.format(model, battle_manager)
	intent_text.text = formatted.text
	intent_tooltip.bbcode_text = formatted.tooltip

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
