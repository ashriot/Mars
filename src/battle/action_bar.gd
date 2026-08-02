extends Control
class_name ActionBar

signal slide_finished
signal action_selected(button, target)
signal action_cancelled
signal shift_button_pressed(direction)
signal availability_changed

const ACTION_CONTROL_HEIGHT_DESKTOP := 86.0
const ACTION_CONTROL_HEIGHT_COMPACT := 86.0
const HEADER_FONT_SIZE_DESKTOP := 20
const HEADER_FONT_SIZE_COMPACT := 24

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
var active_hero: HeroCombatant
var buttons_disabled: bool


func _ready():
	DisplayProfile.bind(apply_display_profile)
	battle_manager.battle_state_changed.connect(_on_state_changed)
	left_shift_button.pressed.connect(_on_shift_button_pressed.bind("left"))
	right_shift_button.pressed.connect(_on_shift_button_pressed.bind("right"))

	left_shift_on_screen_pos = left_shift_ui.position
	right_shift_on_screen_pos = right_shift_ui.position
	actions_on_screen_pos = actions_ui.position
	left_shift_ui.modulate.a = 0.0
	right_shift_ui.modulate.a = 0.0
	actions_ui.modulate.a = 0.0
	buttons_disabled = false

	slide_out(0.0)


func apply_display_profile(profile: int, _window_size: Vector2i, _logical_size: Vector2) -> void:
	var compact := profile == DisplayProfileService.Profile.COMPACT
	var control_height := (
		ACTION_CONTROL_HEIGHT_COMPACT if compact else ACTION_CONTROL_HEIGHT_DESKTOP
	)
	var header_size := HEADER_FONT_SIZE_COMPACT if compact else HEADER_FONT_SIZE_DESKTOP
	for path in ["Actions/Passive", "Actions/ShiftAction", "LeftShift", "RightShift"]:
		var control := get_node_or_null(path) as Control
		if control:
			control.custom_minimum_size.y = control_height
	for path in [
		"Actions/Passive/Header",
		"Actions/ShiftAction/Header",
		"LeftShift/Header",
		"RightShift/Header",
	]:
		var header := get_node_or_null(path) as Label
		if header:
			header.add_theme_font_size_override(&"font_size", header_size)
	if actions_ui:
		for child in actions_ui.get_children():
			if child is ActionButton:
				(child as ActionButton).apply_display_profile(profile)

func load_actions(hero: HeroCombatant, shifted: bool = false):
	active_hero = hero
	if not active_hero.presentation_event.is_connected(_on_hero_presentation_event):
		active_hero.presentation_event.connect(_on_hero_presentation_event)
	update_action_bar(active_hero, shifted)
	await slide_in()

func hide_bar():
	for i in range(4):
		var button = actions_ui.get_child(i) as ActionButton
		if button is not ActionButton: continue
		button.hide()
		if button.pressed.is_connected(_on_action_button_pressed):
			button.pressed.disconnect(_on_action_button_pressed)
	if active_hero.focus_changed.is_connected(_on_hero_focus_updated):
		active_hero.focus_changed.disconnect(_on_hero_focus_updated)

	await slide_out()

func update_action_bar(hero: HeroCombatant, shifted: bool = false):
	if not hero:
		return

	var current_role: RoleData = hero.get_current_role()
	if not current_role:
		push_error("Hero has no role!")
		return
	if hero.focus_changed.is_connected(_on_hero_focus_updated):
		hero.focus_changed.disconnect(_on_hero_focus_updated)
	hero.focus_changed.connect(_on_hero_focus_updated)

	for i in range(4):
		var button = actions_ui.get_child(i) as ActionButton
		button.hide()
		if i >= current_role.actions.size(): continue
		var action_data = current_role.actions[i]
		if not action_data: continue
		if button.pressed.is_connected(_on_action_button_pressed):
			button.pressed.disconnect(_on_action_button_pressed)
		button.pressed.connect(_on_action_button_pressed.bind(button))
		button.setup(action_data, hero, hero.get_scaled_focus_cost(action_data.focus_cost),current_role.color)
		button.show()

	if current_role.passive:
		$Actions/Passive/Title.text = current_role.passive.action_name
		$Actions/Passive/Mask/Icon.texture = current_role.passive.icon
		passive_panel.modulate = current_role.color
		passive_panel.modulate.a = 0.75
		$Actions/Passive/RichTooltip.bbcode_text = current_role.passive.get_rich_description(hero)
		passive_panel.show()
	else:
		passive_panel.hide()

	if current_role.shift_action:
		$Actions/ShiftAction/Title.text = current_role.shift_action.action_name
		$Actions/ShiftAction/Mask/Icon.texture = current_role.shift_action.icon
		shift_action_panel.modulate = current_role.color
		shift_action_panel.modulate.a = 0.75
		$Actions/ShiftAction/RichTooltip.bbcode_text = current_role.shift_action.get_rich_description(hero)
		shift_action_panel.show()
		var pending = ! hero.get_current_role().shift_action.auto_target
		if shifted:
			if pending:
				start_flashing_panel(shift_action_panel)
			else:
				flash_panel(shift_action_panel)
	else:
		shift_action_panel.hide()

	var prev_role: RoleData = hero.get_previous_role()
	var next_role: RoleData = hero.get_next_role()

	left_shift_ui.visible = prev_role != null
	right_shift_ui.visible = next_role != null

	if prev_role:
		$LeftShift/Title.text = prev_role.role_name
		left_shift_button.disabled = prev_role == current_role or next_role == prev_role or left_shift_button.disabled
		left_shift_ui.get_node("RichTooltip").bbcode_text  = prev_role.description
		left_shift_ui.modulate = prev_role.color
		$LeftShift/Mask/Icon.texture = prev_role.icon
		left_shift_button.disabled = active_hero.shifted_this_turn

	if next_role:
		$RightShift/Title.text = next_role.role_name
		right_shift_button.disabled = next_role == current_role or next_role == prev_role or right_shift_button.disabled
		right_shift_ui.get_node("RichTooltip").bbcode_text = next_role.description
		right_shift_ui.modulate = next_role.color
		$RightShift/Mask/Icon.texture = next_role.icon
		right_shift_button.disabled = active_hero.shifted_this_turn
	availability_changed.emit()

func _on_hero_focus_updated(_hero: HeroCombatant):
	if not active_hero: return
	for i in range(4):
		var button = actions_ui.get_child(i) as ActionButton
		button.update_cost(active_hero.current_focus)
	availability_changed.emit()

func _on_shift_button_pressed(direction: String):
	shift_button_pressed.emit(direction)

func _on_action_button_pressed(button: ActionButton):
	action_selected.emit(button)


func activate_slot(index: int) -> bool:
	if index < 0 or index >= 4 or not actions_ui or index >= actions_ui.get_child_count():
		return false
	var action_button := actions_ui.get_child(index) as ActionButton
	if action_button == null or not action_button.visible or action_button.disabled:
		return false
	_on_action_button_pressed(action_button)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if buttons_disabled or sliding or not visible or (battle_manager and battle_manager.current_state != BattleManager.State.PLAYER_ACTION) or _modal_is_open():
		return
	for index in 4:
		if event.is_action_pressed(StringName("action_%d" % (index + 1))):
			var action_button := actions_ui.get_child(index) as ActionButton if actions_ui and index < actions_ui.get_child_count() else null
			if battle_manager and battle_manager.current_action != null:
				if event.is_action_pressed(&"confirm") or event.is_action_pressed(&"cancel"):
					return
				if action_button == battle_manager.focused_button:
					action_cancelled.emit()
					if is_inside_tree():
						get_viewport().set_input_as_handled()
					return
			if activate_slot(index) and is_inside_tree():
				get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"shift_left"):
		if activate_shift("left") and is_inside_tree():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"shift_right"):
		if activate_shift("right") and is_inside_tree():
			get_viewport().set_input_as_handled()
		return


func activate_shift(direction: String) -> bool:
	var shift_ui: Control = left_shift_ui if direction == "left" else right_shift_ui if direction == "right" else null
	var shift_button: Button = left_shift_button if direction == "left" else right_shift_button if direction == "right" else null
	if shift_ui == null or not shift_ui.visible or shift_button == null or shift_button.disabled:
		return false
	_on_shift_button_pressed(direction)
	return true


func _modal_is_open() -> bool:
	if not is_inside_tree() or get_tree() == null:
		return false
	var navigation := get_tree().root.find_child("NavigationUXLayer", true, false) as NavigationUXLayer
	return navigation != null and not navigation._modal_stack.is_empty()

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


func _on_hero_presentation_event(
	_hero: BattleCombatant,
	event: StringName,
	_payload: Dictionary,
) -> void:
	if event == &"passive_fired":
		_on_hero_passive_fired()

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
	buttons_disabled = state in [BattleManager.State.FORCED_TARGET]
	for button in actions_ui.get_children():
		if button is ActionButton:
			button.override_disabled = buttons_disabled
	left_shift_button.disabled = buttons_disabled or active_hero.shifted_this_turn
	right_shift_button.disabled = buttons_disabled or active_hero.shifted_this_turn
	$LeftShift/DynamicGlyph.modulate.a = 0.33 if left_shift_button.disabled else 1.0
	$RightShift/DynamicGlyph.modulate.a = 0.33 if right_shift_button.disabled else 1.0
	availability_changed.emit()

func slide_in(duration: float = 0.2):
	sliding = true
	AudioManager.play_sfx("press")
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
