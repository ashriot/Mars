extends Control

@export var game_scene: PackedScene

@onready var red_label: Label = $Title/Red
@onready var start_button: Button = $MenuButtons/BtnStart
@onready var continue_button: Button = $MenuButtons/BtnContinue
@onready var load_button: Button = $MenuButtons/BtnLoad
@onready var chroma_rect: ColorRect = $TextureRect/ChromaRect
@onready var menu_buttons: VBoxContainer = $MenuButtons

func _ready():
	self.modulate.a = 0.0
	for child in menu_buttons.get_children():
		child = child as Button
		#child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if SaveSystem.has_save(1):
		continue_button.disabled = false
	else:
		continue_button.disabled = true

	chroma_rect.modulate.a = 0.0
	menu_buttons.modulate.a = 1.0

	var tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

	#await get_tree().create_timer(0.25).timeout

	tween = create_tween().set_parallel()
	tween.tween_property(chroma_rect, "modulate:a", 0.75, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_buttons, "modulate:a", 1.0, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(red_label, "modulate", Color.ORANGE_RED, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

	for child in menu_buttons.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_new_game_pressed():
	SaveSystem.start_new_campaign(1)
	_start_dungeon_run()

func _on_continue_pressed():
	if SaveSystem.load_game(1):
		var location = SaveSystem.data.meta_data.location

		if SaveSystem.data.active_run != null:
			_resume_dungeon_run()
		else:
			_load_hub_scene()

func _start_dungeon_run():
	RunManager.is_run_active = false
	_transition_to_game()

func _resume_dungeon_run():
	RunManager.is_run_active = true
	_transition_to_game()

func _transition_to_game():
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

	get_tree().change_scene_to_packed(game_scene)

func _load_hub_scene():
	print("Hub not implemented yet. Starting fresh dungeon run.")
	_start_dungeon_run()
