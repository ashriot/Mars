extends Control

signal action_selected(action, target)
signal shift_button_pressed(direction)

@onready var actions_ui = $Actions
@onready var left_shift_button = $LeftShift/Button
@onready var right_shift_button = $RightShift/Button
@onready var left_shift_ui = $LeftShift
@onready var right_shift_ui = $RightShift
@export var ActionButtonScene : PackedScene
@export var battle_manager : BattleManager

var left_shift_on_screen_pos: Vector2
var right_shift_on_screen_pos: Vector2
var actions_on_screen_pos: Vector2


func _ready():
	battle_manager.player_turn_started.connect(on_player_turn_started)
	hide()
	left_shift_button.pressed.connect(_on_shift_button_pressed.bind("left"))
	right_shift_button.pressed.connect(_on_shift_button_pressed.bind("right"))

	left_shift_on_screen_pos = left_shift_ui.position
	right_shift_on_screen_pos = right_shift_ui.position
	actions_on_screen_pos = actions_ui.position
	left_shift_ui.modulate.a = 0.0
	right_shift_ui.modulate.a = 0.0
	actions_ui.modulate.a = 0.0

	hide()
	slide_out(0.0)

func on_player_turn_started(hero_card: HeroCard):
	if not hero_card.role_shifted.is_connected(update_action_bar):
		hero_card.role_shifted.connect(update_action_bar)
	update_action_bar(hero_card)
	show()

func hide_bar():
	for button in actions_ui.get_children():
		button.hide()
		if button.pressed.is_connected(_on_action_button_pressed):
			button.pressed.disconnect(_on_action_button_pressed)
	await slide_out()
	hide()

func update_action_bar(hero_card: HeroCard):
	if not hero_card:
		return

	var current_role: Role = hero_card.get_current_role()
	if not current_role:
		push_error("Hero has no role!")
		return

	for i in range(4):
		var button = actions_ui.get_child(i) as ActionButton
		button.hide()
		var action_data = current_role.actions[i]
		if not action_data: continue
		if button.pressed.is_connected(_on_action_button_pressed):
			button.pressed.disconnect(_on_action_button_pressed)
		button.pressed.connect(_on_action_button_pressed.bind(action_data))
		button.setup(action_data, hero_card.current_focus_pips)
		button.show()

	var prev_role: Role = hero_card.get_previous_role()
	var next_role: Role = hero_card.get_next_role()

	if prev_role:
		$LeftShift/Title.text = prev_role.role_name
		left_shift_button.disabled = prev_role == current_role

	if next_role:
		$RightShift/Title.text = next_role.role_name
		right_shift_button.disabled = next_role == current_role or next_role == prev_role

func _on_shift_button_pressed(direction: String):
	shift_button_pressed.emit(direction)
	await slide_out()
	slide_in()

func _on_action_button_pressed(action_data: Action):
	action_selected.emit(action_data)

func slide_in(duration: float = 0.2):
	var tween = create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_SINE)

	var left_off_screen = left_shift_on_screen_pos - Vector2(left_shift_ui.size.x, 0)
	left_shift_ui.position = left_off_screen # Set start pos
	tween.tween_property(left_shift_ui, "position", left_shift_on_screen_pos, duration)
	tween.tween_property(left_shift_ui, "modulate:a", 1.0, duration)

	var right_off_screen = right_shift_on_screen_pos + Vector2(right_shift_ui.size.x, 0)
	right_shift_ui.position = right_off_screen # Set start pos
	tween.tween_property(right_shift_ui, "position", right_shift_on_screen_pos, duration)
	tween.tween_property(right_shift_ui, "modulate:a", 1.0, duration)

	# 3. Actions slide in FROM the bottom
	var actions_off_screen = actions_on_screen_pos + Vector2(0, actions_ui.size.y)
	actions_ui.position = actions_off_screen # Set start pos
	tween.tween_property(actions_ui, "position", actions_on_screen_pos, duration)
	tween.tween_property(actions_ui, "modulate:a", 1.0, duration)

	await tween.finished

# This function animates all 3 pieces out
func slide_out(duration: float = 0.2):
	var tween = create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_SINE)

	# 1. Left Shift slides back to the left
	var left_off_screen = left_shift_on_screen_pos - Vector2(left_shift_ui.size.x, 0)
	tween.tween_property(left_shift_ui, "position", left_off_screen, duration)
	tween.tween_property(left_shift_ui, "modulate:a", 0.0, duration)

	# 2. Right Shift slides back to the right
	var right_off_screen = right_shift_on_screen_pos + Vector2(right_shift_ui.size.x, 0)
	tween.tween_property(right_shift_ui, "position", right_off_screen, duration)
	tween.tween_property(right_shift_ui, "modulate:a", 0.0, duration)

	# 3. Actions slide back to the bottom
	var actions_off_screen = actions_on_screen_pos + Vector2(0, actions_ui.size.y)
	tween.tween_property(actions_ui, "position", actions_off_screen, duration)
	tween.tween_property(actions_ui, "modulate:a", 0.0, duration)

	await tween.finished
