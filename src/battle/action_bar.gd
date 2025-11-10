extends Control

signal action_selected(action, target)
signal shift_button_pressed(direction)


@onready var anim = $AnimationPlayer
@onready var button_container = $Actions
@onready var left_shift_button = $LeftShift/Button
@onready var right_shift_button = $RightShift/Button
# @onready var left_shift_ui = $LeftShift # (You'll use these in update_action_bar)
# @onready var right_shift_ui = $RightShift # (You'll use these in update_action_bar)
@export var ActionButtonScene : PackedScene
@export var battle_manager : BattleManager


func _ready():
	battle_manager.player_turn_started.connect(on_player_turn_started)
	hide()
	left_shift_button.pressed.connect(_on_shift_button_pressed.bind("left"))
	right_shift_button.pressed.connect(_on_shift_button_pressed.bind("right"))

func on_player_turn_started(hero_card: HeroCard):
	if not hero_card.role_shifted.is_connected(update_action_bar):
		hero_card.role_shifted.connect(update_action_bar)
	update_action_bar(hero_card)
	show()
	anim.play("fade_in")

func hide_bar():
	anim.play("fade_out")
	await anim.animation_finished
	hide()

	for child in button_container.get_children():
		child.queue_free()

func update_action_bar(hero_card: HeroCard):
	if not hero_card:
		return

	for child in button_container.get_children():
		child.queue_free()

	var current_role: Role = hero_card.get_current_role()
	if not current_role:
		push_error("Hero has no role!")
		return

	for action_data in current_role.actions:
		if not action_data: continue
		var button = ActionButtonScene.instantiate()
		button_container.add_child(button)
		button.pressed.connect(_on_action_button_pressed.bind(action_data))
		button.setup(action_data)

	var prev_role: Role = hero_card.get_previous_role()
	var next_role: Role = hero_card.get_next_role()

	if prev_role:
		left_shift_button.get_child(0).text = prev_role.role_name
		left_shift_button.disabled = prev_role == current_role

	if next_role:
		right_shift_button.get_child(0).text = next_role.role_name
		right_shift_button.disabled = next_role == current_role or next_role == prev_role

func _on_shift_button_pressed(direction: String):
	shift_button_pressed.emit(direction)

func _on_action_button_pressed(action_data: Action):
	action_selected.emit(action_data)
