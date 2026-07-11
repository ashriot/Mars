extends Control
class_name TitleScreen

# --- SIGNALS (Signal Up) ---
signal new_game_requested
signal continue_requested

# --- UI REFERENCES ---
@onready var red_label: Label = $Title/Red
@onready var start_button: Button = $MenuButtons/BtnStart
@onready var continue_button: Button = $MenuButtons/BtnContinue
@onready var load_button: Button = $MenuButtons/BtnLoad
@onready var chroma_rect: ColorRect = $TextureRect/ChromaRect
@onready var menu_buttons: VBoxContainer = $MenuButtons

func _ready():
	AudioManager.play_music("title")

	# 1. Setup Initial Visual State
	self.modulate.a = 0.0
	chroma_rect.modulate.a = 0.0
	menu_buttons.modulate.a = 1.0

	# 2. Check Save Status
	if SaveSystem.has_save(1):
		continue_button.disabled = false
	else:
		continue_button.disabled = true

	load_button.disabled = true
	_configure_navigation()

	# 3. Disable Input during Intro
	#for child in menu_buttons.get_children():
		#if child is Control:
			#child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 4. Intro Animation
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

	# 5. Secondary Animation (Flavor)
	tween = create_tween().set_parallel()
	tween.tween_property(chroma_rect, "modulate:a", 0.75, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_buttons, "modulate:a", 1.0, 1.5)
	tween.tween_property(red_label, "modulate", Color.ORANGE_RED, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

	# 6. Enable Input
	for child in menu_buttons.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_STOP


func _exit_tree() -> void:
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.unregister_screen(self)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"confirm"):
		return
	var focused := get_viewport().gui_get_focus_owner() as BaseButton
	if focused and (focused == start_button or focused == continue_button or focused == load_button) and not focused.disabled:
		get_viewport().set_input_as_handled()
		focused.pressed.emit()


func _configure_navigation() -> void:
	var default_focus := continue_button if not continue_button.disabled else start_button
	for button in [start_button, continue_button, load_button]:
		button.focus_entered.connect(_publish_hints)
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.register_screen(self, default_focus)
	_publish_hints()
	_grab_focus_if_valid.call_deferred(default_focus)


func _navigation_ux_layer() -> NavigationUXLayer:
	return get_tree().root.find_child("NavigationUXLayer", true, false) as NavigationUXLayer


func _publish_hints() -> void:
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.publish_hints([{action = &"confirm", label = "Select", enabled = true}])


func _grab_focus_if_valid(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and not (control is BaseButton and control.disabled):
		control.grab_focus()

func _on_new_game_pressed():
	# 1. Initialize Data
	SaveSystem.start_new_campaign(1)

	# 2. Signal Main to handle the transition
	new_game_requested.emit()

func _on_continue_pressed():
	# 1. Attempt Load
	if SaveSystem.load_game(1):
		# 2. Signal Main (Main will decide if we go to Hub or Dungeon)
		continue_requested.emit()
	else:
		print("Error loading save file")
