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
		continue_button.grab_focus() # Nice UX touch
	else:
		continue_button.disabled = true
		start_button.grab_focus()

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
