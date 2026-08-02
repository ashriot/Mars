extends ActorCard
class_name HeroCard

# --- UNIQUE Signals ---
signal hero_clicked(hero_card)
@warning_ignore("unused_signal")
signal passive_fired
signal focus_updated

# --- NEW: Animation Vars ---
@export var slide_offset_y: int = -30
@export var duration: float = 0.2

# --- UNIQUE UI Node References ---
@onready var focus_bar: HBoxContainer = $Panel/FocusBar
@onready var role_label: Label = $Panel/Role
@onready var role_icon: TextureRect = $Panel/RoleIcon

# --- Temporary model-backed compatibility properties ---
var hero_data: HeroData:
	get: return (combatant as HeroCombatant).hero_data
var loaded_roles: Array[RoleData]:
	get: return (combatant as HeroCombatant).loaded_roles
var current_role_index: int:
	get: return (combatant as HeroCombatant).current_role_index
var current_focus: int:
	get: return (combatant as HeroCombatant).current_focus
var shifted_this_turn: bool:
	get: return (combatant as HeroCombatant).shifted_this_turn


func setup(data: HeroData) -> void:
	_ensure_battle_manager()
	var model := HeroCombatant.new()
	add_child(model)
	model.setup(data, battle_manager)
	await setup_from_combatant(model)


func setup_from_combatant(model: HeroCombatant) -> void:
	_ensure_battle_manager()
	bind_combatant(model)
	model.focus_changed.connect(_on_focus_changed)
	model.presentation_event.connect(_on_hero_presentation_event)
	await _setup_card_visuals()
	_render_hero_state()


func _render_hero_state() -> void:
	if hero_data.portrait:
		portrait_rect.texture = hero_data.portrait
	if is_instance_valid(battle_manager):
		duration /= battle_manager.battle_speed
	name_label.text = hero_data.stats.actor_name
	update_focus_bar(false)
	update_current_role()
	panel.self_modulate.a = 1.0


func _on_focus_changed(_hero: HeroCombatant) -> void:
	update_focus_bar()
	focus_updated.emit()


func _on_hero_presentation_event(
	_hero: BattleCombatant,
	event: StringName,
	_payload: Dictionary,
) -> void:
	if event == &"role_changed":
		update_current_role()

func on_turn_started() -> void:
	#if current_focus < 10:
		#modify_focus(1)
	(combatant as HeroCombatant).shifted_this_turn = false
	await _slide_up()
	await battle_manager.action_bar.load_actions(combatant as HeroCombatant, false)
	await super.on_turn_started()
	if is_breached:
		recover_breach()
	return

func on_turn_ended() -> void:
	_slide_down()
	await super.on_turn_ended()

func _show_defeated_visual(_immediate: bool = false) -> void:
	self_modulate.a = 0.25


func _show_revived_visual() -> void:
	print(actor_name, " is revived!")
	self_modulate = Color.WHITE

func get_current_role() -> RoleData:
	return (combatant as HeroCombatant).get_current_role()

func get_previous_role() -> RoleData:
	return (combatant as HeroCombatant).get_previous_role()

func get_next_role() -> RoleData:
	return (combatant as HeroCombatant).get_next_role()

func shift_role(direction: String) -> void:
	await (combatant as HeroCombatant).shift_role(direction)

func update_current_role():
	var role := get_current_role()
	if role == null:
		role_label.text = ""
		role_icon.texture = null
		return
	role_label.text = role.role_name
	role_icon.texture = role.icon
	recolor()

func modify_focus(amount: int, context: Dictionary = {}) -> void:
	await (combatant as HeroCombatant).modify_focus(amount, context)

func update_focus_bar(animate: bool = true):
	var pips = focus_bar.get_children()

	for i in pips.size():
		var pip_node = pips[i]

		if i < current_focus:
			if not pip_node.visible or pip_tweens.has(pip_node):
				_animate_pip_gain(pip_node, animate)
		elif pip_node.visible or pip_tweens.has(pip_node):
			_animate_pip_loss(pip_node, animate)

func get_scaled_focus_cost(cost: int) -> int:
	return (combatant as HeroCombatant).get_scaled_focus_cost(cost)

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
		print("Clicked on: ", actor_name)
		hero_clicked.emit(self)
		get_viewport().set_input_as_handled()

func recolor():
	var color = get_current_role().color
	panel.self_modulate = color
	#$Panel/HP/HeartIcon.self_modulate = color
	#name_label.self_modulate = color
	role_label.self_modulate = color
	role_icon.self_modulate = color
	focus_bar.modulate = color
	guard_bar.modulate = color
	highlight_panel.modulate = Color.WHITE
