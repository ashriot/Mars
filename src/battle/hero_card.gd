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

# --- UNIQUE Data ---
var hero_data: HeroData
var current_focus: int = 0
var current_role_index: int = 0
var shifted_this_turn: bool
var blink_tween: Tween

func setup(data: HeroData):
	hero_data = data
	hero_data.calculate_stats()
	setup_base(hero_data.stats)
	duration /= battle_manager.battle_speed
	name_label.text = hero_data.stats.actor_name
	if hero_data.portrait:
		portrait_rect.texture = hero_data.portrait
	current_focus = 4
	update_focus_bar(false)
	update_current_role()
	panel.self_modulate.a = 1.0

func on_turn_started() -> void:
	#if current_focus < 10:
		#modify_focus(1)
	shifted_this_turn = false
	await _slide_up()
	await battle_manager.action_bar.load_actions(self, false)
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

func get_current_role() -> RoleData:
	if hero_data.unlocked_roles.size() > 0:
		return hero_data.unlocked_roles[current_role_index]
	return null

func get_previous_role() -> RoleData:
	var role_count = hero_data.unlocked_roles.size()
	if role_count == 0: return null
	var prev_index = (current_role_index - 1 + role_count) % role_count
	return hero_data.unlocked_roles[prev_index]

func get_next_role() -> RoleData:
	var role_count = hero_data.unlocked_roles.size()
	if role_count == 0: return null
	var next_index = (current_role_index + 1) % role_count
	return hero_data.unlocked_roles[next_index]

func shift_role(direction: String):
	shifted_this_turn = true
	var role_count = hero_data.unlocked_roles.size()
	if role_count == 0: return

	if direction == "left":
		current_role_index = (current_role_index - 1 + role_count) % role_count
	else:
		current_role_index = (current_role_index + 1) % role_count
	update_current_role()
	start_blinking()
	await _fire_condition_event(Trigger.TriggerType.ON_SHIFT)

func update_current_role():
	role_label.text = get_current_role().role_name.to_upper()
	role_icon.texture = get_current_role().icon
	recolor()

func modify_focus(amount: int):
	current_focus += amount
	current_focus = clamp(current_focus, 0, 10)
	update_focus_bar()
	focus_updated.emit()

	await _fire_condition_event(Trigger.TriggerType.ON_SPENDING_FOCUS)

func update_focus_bar(animate: bool = true):
	var pips = focus_bar.get_children()

	for i in pips.size():
		var pip_node = pips[i]

		if i < current_focus:
			if not pip_node.visible:
				_animate_pip_gain(pip_node)
		elif pip_node.visible:
			if animate:
				_animate_pip_loss(pip_node)
			else:
				pip_node.hide()

func get_scaled_focus_cost(cost: int) -> int:
	var scalar: float = 1.0
	for condition in active_conditions:
		scalar -= condition.focus_cost_reduction
	return int(cost * scalar)

func highlight(value: bool):
	if value:
		start_blinking()
	else:
		stop_blinking()
	highlight_panel.visible = value

func start_blinking():
	if blink_tween and blink_tween.is_running():
		blink_tween.kill()
	var color: Color = get_current_role().color
	var bright_color = color + Color(1.0, 1.0, 1.0)

	blink_tween = create_tween().set_loops()

	blink_tween.tween_property(
		highlight_panel,
		"modulate",
		bright_color,
		0.4 / battle_manager.battle_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	blink_tween.tween_property(
		highlight_panel,
		"modulate",
		get_current_role().color,
		0.4 / battle_manager.battle_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_blinking():
	if blink_tween and blink_tween.is_running():
		blink_tween.kill()
		blink_tween = null

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
	#name_label.self_modulate = color
	role_label.self_modulate = color
	role_icon.self_modulate = color
	focus_bar.modulate = color
	guard_bar.modulate = color
	highlight_panel.modulate = color
