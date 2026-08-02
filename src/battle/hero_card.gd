extends ActorCard
class_name HeroCard

# --- UNIQUE Signals ---
signal hero_clicked(hero_card)

# --- NEW: Animation Vars ---
@export var slide_offset_y: int = -30
@export var duration: float = 0.2

# --- UNIQUE UI Node References ---
@onready var focus_bar: HBoxContainer = $Panel/FocusBar
@onready var role_label: Label = $Panel/Role
@onready var role_icon: TextureRect = $Panel/RoleIcon

func setup_from_combatant(model: HeroCombatant) -> void:
	_ensure_battle_manager()
	if not bind_combatant(model):
		return
	model.focus_changed.connect(_on_focus_changed)
	model.presentation_event.connect(_on_hero_presentation_event)
	await _setup_card_visuals()
	_render_hero_state()


func _render_hero_state() -> void:
	var model := combatant as HeroCombatant
	if model.hero_data.portrait:
		portrait_rect.texture = model.hero_data.portrait
	if is_instance_valid(battle_manager):
		duration /= battle_manager.battle_speed
	name_label.text = model.hero_data.stats.actor_name
	update_focus_bar(false)
	update_current_role()
	panel.self_modulate.a = 1.0


func _on_focus_changed(_hero: HeroCombatant) -> void:
	update_focus_bar()


func _on_hero_presentation_event(
	_hero: BattleCombatant,
	event: StringName,
	_payload: Dictionary,
) -> void:
	if event == &"role_changed":
		update_current_role()

func _show_defeated_visual(_immediate: bool = false) -> void:
	self_modulate.a = 0.25


func _show_revived_visual() -> void:
	print(_require_combatant().actor_name, " is revived!")
	self_modulate = Color.WHITE

func update_current_role():
	var role := (combatant as HeroCombatant).get_current_role()
	if role == null:
		role_label.text = ""
		role_icon.texture = null
		return
	role_label.text = role.role_name
	role_icon.texture = role.icon
	recolor()

func update_focus_bar(animate: bool = true):
	var pips = focus_bar.get_children()
	var current_focus := (combatant as HeroCombatant).current_focus

	for i in pips.size():
		var pip_node = pips[i]

		if i < current_focus:
			if not pip_node.visible or pip_tweens.has(pip_node):
				_animate_pip_gain(pip_node, animate)
		elif pip_node.visible or pip_tweens.has(pip_node):
			_animate_pip_loss(pip_node, animate)

func highlight(value: bool):
	highlight_panel.visible = value

func _slide_up():
	var tween = create_tween().set_parallel()
	tween.tween_property(
		panel,
		"position",
		panel_home_position + Vector2(0, slide_offset_y),
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "self_modulate:a", 1.0, duration)

func _slide_down():
	var tween = create_tween().set_parallel()
	tween.tween_property(
		panel,
		"position",
		panel_home_position,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "self_modulate:a", 1.0, duration)

func _on_gui_input(event: InputEvent):
	if event.is_action_pressed("ui_accept"):
		print("Clicked on: ", _require_combatant().actor_name)
		hero_clicked.emit(self)
		get_viewport().set_input_as_handled()

func recolor():
	var color = (combatant as HeroCombatant).get_current_role().color
	panel.self_modulate = color
	#$Panel/HP/HeartIcon.self_modulate = color
	#name_label.self_modulate = color
	role_label.self_modulate = color
	role_icon.self_modulate = color
	focus_bar.modulate = color
	guard_bar.modulate = color
	highlight_panel.modulate = Color.WHITE
