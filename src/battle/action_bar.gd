extends Control
class_name ActionBar

signal slide_finished
signal action_selected(button, target)
signal shift_button_pressed(direction)

@export var ActionButtonScene : PackedScene
@export var battle_manager : BattleManager

@onready var actions_ui = $Actions
@onready var left_shift_button: Button = $LeftShift/Button
@onready var right_shift_button: Button = $RightShift/Button
@onready var left_shift_ui = $LeftShift
@onready var right_shift_ui = $RightShift
@onready var passive_panel: Panel = $Actions/Passive
@onready var shift_action_panel: Panel = $Actions/ShiftAction

var sliding: bool
var left_shift_on_screen_pos: Vector2
var right_shift_on_screen_pos: Vector2
var actions_on_screen_pos: Vector2
var passive_flash_tween: Tween
var flashing_tween: Tween
var active_hero: HeroCard


func _ready():
	battle_manager.battle_state_changed.connect(_on_state_changed)
	left_shift_button.pressed.connect(_on_shift_button_pressed.bind("left"))
	right_shift_button.pressed.connect(_on_shift_button_pressed.bind("right"))

	left_shift_on_screen_pos = left_shift_ui.position
	right_shift_on_screen_pos = right_shift_ui.position
	actions_on_screen_pos = actions_ui.position
	left_shift_ui.modulate.a = 0.0
	right_shift_ui.modulate.a = 0.0
	actions_ui.modulate.a = 0.0

	slide_out(0.0)

func load_actions(hero_card: HeroCard, shifted: bool = false):
	active_hero = hero_card
	if not active_hero.passive_fired.is_connected(_on_hero_passive_fired):
		active_hero.passive_fired.connect(_on_hero_passive_fired)
	update_action_bar(active_hero, shifted)
	await slide_in()

func hide_bar():
	for i in range(4):
		var button = actions_ui.get_child(i) as ActionButton
		if button is not ActionButton: continue
		button.hide()
		if button.pressed.is_connected(_on_action_button_pressed):
			button.pressed.disconnect(_on_action_button_pressed)
	if active_hero.focus_updated.is_connected(_on_hero_focus_updated):
		active_hero.focus_updated.disconnect(_on_hero_focus_updated)

	await slide_out()

func update_action_bar(hero_card: HeroCard, shifted: bool = false):
	if not hero_card:
		return

	var current_role: RoleData = hero_card.get_current_role()
	if not current_role:
		push_error("Hero has no role!")
		return
	if hero_card.focus_updated.is_connected(_on_hero_focus_updated):
		hero_card.focus_updated.disconnect(_on_hero_focus_updated)
	hero_card.focus_updated.connect(_on_hero_focus_updated)

	for i in range(4):
		var button = actions_ui.get_child(i) as ActionButton
		button.hide()
		var action_data = current_role.actions[i]
		if not action_data: continue
		if button.pressed.is_connected(_on_action_button_pressed):
			button.pressed.disconnect(_on_action_button_pressed)
		button.pressed.connect(_on_action_button_pressed.bind(button))
		button.setup(action_data, hero_card.current_focus, hero_card.get_scaled_focus_cost(action_data.focus_cost),current_role.color)
		button.show()

	if current_role.passive:
		$Actions/Passive/Title.text = current_role.passive.action_name
		$Actions/Passive/Mask/Icon.texture = current_role.passive.icon
		passive_panel.modulate = current_role.color
		passive_panel.modulate.a = 0.75
		passive_panel.tooltip_text = current_role.passive.description
		passive_panel.show()
	else:
		passive_panel.hide()

	if current_role.shift_action:
		$Actions/ShiftAction/Title.text = current_role.shift_action.action_name
		$Actions/ShiftAction/Mask/Icon.texture = current_role.shift_action.icon
		shift_action_panel.modulate = current_role.color
		shift_action_panel.modulate.a = 0.75
		shift_action_panel.tooltip_text = current_role.shift_action.description
		shift_action_panel.show()
		var pending = ! hero_card.get_current_role().shift_action.auto_target
		if shifted:
			if pending:
				start_flashing_panel(shift_action_panel)
			else:
				flash_panel(shift_action_panel)
	else:
		shift_action_panel.hide()

	var prev_role: RoleData = hero_card.get_previous_role()
	var next_role: RoleData = hero_card.get_next_role()

	left_shift_ui.visible = prev_role != null
	right_shift_ui.visible = next_role != null

	if prev_role:
		$LeftShift/Title.text = prev_role.role_name
		left_shift_button.disabled = prev_role == current_role or next_role == prev_role or left_shift_button.disabled
		left_shift_button.tooltip_text = prev_role.description
		left_shift_ui.modulate = prev_role.color
		$LeftShift/Mask/Icon.texture = prev_role.icon
		left_shift_button.disabled = active_hero.shifted_this_turn

	if next_role:
		$RightShift/Title.text = next_role.role_name
		right_shift_button.disabled = next_role == current_role or next_role == prev_role or right_shift_button.disabled
		right_shift_button.tooltip_text = next_role.description
		right_shift_ui.modulate = next_role.color
		$RightShift/Mask/Icon.texture = next_role.icon
		right_shift_button.disabled = active_hero.shifted_this_turn

func _on_hero_focus_updated():
	if not active_hero: return
	for i in range(4):
		var button = actions_ui.get_child(i) as ActionButton
		button.update_cost(active_hero.current_focus)

func _on_shift_button_pressed(direction: String):
	shift_button_pressed.emit(direction)

func _on_action_button_pressed(button: ActionButton):
	action_selected.emit(button)

func flash_panel(panel: Panel):
	var base_color = panel.modulate
	var flash_color = Color(3.0, 3.0, 3.0, 1.0)

	if passive_flash_tween and passive_flash_tween.is_running():
		passive_flash_tween.kill()

	passive_flash_tween = create_tween()
	panel.modulate = flash_color
	passive_flash_tween.tween_property(
		panel,
		"modulate",
		base_color,
		0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_hero_passive_fired():
	flash_panel(passive_panel)

func start_flashing_panel(panel: Panel):
	panel.modulate.a = 0.0

	if flashing_tween and flashing_tween.is_running():
		flashing_tween.kill()

	flashing_tween = create_tween().set_loops()

	flashing_tween.tween_property(
		panel,
		"modulate:a",
		1.0,
		0.2 / battle_manager.battle_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	flashing_tween.tween_property(
		panel,
		"modulate:a",
		0.4,
		0.6 / battle_manager.battle_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_flashing_panel():
	if flashing_tween and flashing_tween.is_running():
		flashing_tween.kill()
		flashing_tween = null

	shift_action_panel.modulate.a = 0.5

func _on_state_changed(state: BattleManager.State):
	if not active_hero: return
	var is_forced = state == BattleManager.State.FORCED_TARGET
	for button in actions_ui.get_children():
		if button is ActionButton:
			button.disabled = is_forced
	left_shift_button.disabled = is_forced or active_hero.shifted_this_turn
	right_shift_button.disabled = is_forced or active_hero.shifted_this_turn

func slide_in(duration: float = 0.2):
	sliding = true
	duration = duration / battle_manager.battle_speed

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
	slide_finished.emit()
	sliding = false

func slide_out(duration: float = 0.2):
	sliding = true
	duration = duration / battle_manager.battle_speed
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
	slide_finished.emit()
	sliding = false
