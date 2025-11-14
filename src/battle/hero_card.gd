extends ActorCard
class_name HeroCard

# --- UNIQUE Signals ---
signal role_shifted(hero_card)
signal focus_changed(new_pips)
signal hero_clicked(hero_card)

# --- UNIQUE Data ---
var hero_data: HeroData
var current_focus_pips: int = 0
var current_role_index: int = 0

# --- NEW: Animation Vars ---
@export var slide_offset_y: int = -30
@export var duration: float = 0.2

# --- UNIQUE UI Node References ---
@onready var focus_bar: HBoxContainer = $Panel/FocusBar
@onready var role_label: Label = $Panel/Role
@onready var role_icon: TextureRect = $Panel/RoleIcon

func setup(data: HeroData):
	hero_data = data
	setup_base(data.stats)
	duration /= battle_manager.battle_speed
	name_label.text = hero_data.stats.actor_name
	role_label.text = get_current_role().role_name
	role_icon.texture = get_current_role().icon
	panel.self_modulate.a = 0.7
	recolor()
	if hero_data.portrait:
		portrait_rect.texture = hero_data.portrait
	current_focus_pips = 2
	update_focus_bar()

func on_turn_started() -> void:
	if current_focus_pips < 10:
		current_focus_pips += 1
		update_focus_bar()
	await _slide_up()
	await battle_manager.action_bar.load_actions(self)
	await super.on_turn_started()
	return

func on_turn_ended() -> void:
	_slide_down()
	await super.on_turn_ended()

func take_healing(heal_amount: int, is_revive: bool = false):
	if is_defeated and is_revive:
		print(actor_name, " is revived!")
		is_defeated = false
		self_modulate = Color.WHITE
		actor_revived.emit(self)

	super.take_healing(heal_amount, is_revive)

func defeated():
	super.defeated()
	self_modulate.a = 0.25

func get_current_role() -> Role:
	if hero_data.unlocked_roles.size() > 0:
		return hero_data.unlocked_roles[current_role_index]
	return null

func get_previous_role() -> Role:
	var role_count = hero_data.unlocked_roles.size()
	if role_count == 0: return null
	var prev_index = (current_role_index - 1 + role_count) % role_count
	return hero_data.unlocked_roles[prev_index]

func get_next_role() -> Role:
	var role_count = hero_data.unlocked_roles.size()
	if role_count == 0: return null
	var next_index = (current_role_index + 1) % role_count
	return hero_data.unlocked_roles[next_index]

func shift_role(direction: String):
	var role_count = hero_data.unlocked_roles.size()
	if role_count == 0: return

	if direction == "left":
		current_role_index = (current_role_index - 1 + role_count) % role_count
	else:
		current_role_index = (current_role_index + 1) % role_count
	role_label.text = get_current_role().role_name
	role_icon.texture = get_current_role().icon
	await _fire_condition_event(Trigger.TriggerType.ON_SHIFT)
	role_shifted.emit(self)
	recolor()

func spend_focus(amount: int):
	current_focus_pips -= amount
	update_focus_bar()
	await _fire_condition_event(Trigger.TriggerType.ON_SPENDING_FOCUS)

func update_focus_bar():
	var pips = focus_bar.get_children()
	for i in pips.size():
		if i < current_focus_pips:
			pips[i].visible = true
		else:
			pips[i].visible = false
	focus_changed.emit(current_focus_pips)

func get_scaled_focus_cost(cost: int) -> int:
	if has_condition("Preparation"):
		return int(cost / 2)
	return cost

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
	tween.tween_property(panel, "self_modulate:a", 0.7, duration)

func _on_gui_input(event: InputEvent):
	if event.is_action_pressed("ui_accept"):
		print("Clicked on: ", actor_name)
		hero_clicked.emit(self)
		get_viewport().set_input_as_handled()

func recolor():
	var color = get_current_role().color
	panel.self_modulate = color
	#name_label.self_modulate = color
	role_label.self_modulate = color
	role_icon.self_modulate = color
	focus_bar.modulate = color
	guard_bar.modulate = color
	highlight_panel.modulate = color
