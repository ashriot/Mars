extends Control

@export var game_scene: PackedScene

@onready var continue_button: Button = $VBoxContainer/BtnContinue
@onready var chroma_rect: ColorRect = $TextureRect/ChromaRect


func _ready():
	# Simple check for Slot 1 for a "Quick Continue"
	if SaveSystem.has_save(1):
		continue_button.disabled = false
	else:
		continue_button.disabled = true
	chroma_rect.modulate.a = 0.0
	$VBoxContainer.modulate.a = 0.0
	await get_tree().create_timer(1.0).timeout

	var tween = create_tween().set_parallel()
	tween.tween_property(chroma_rect, "modulate:a", 1.0, 2.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property($VBoxContainer, "modulate:a", 1.0, 2.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property($Red, "modulate", Color.ORANGE_RED, 2.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

func _on_new_game_pressed():
	# 1. Create the data for Slot 1 (or ask user for slot)
	SaveSystem.start_new_campaign(1)

	# 2. Since it's a new game, we might go to a "Hub" or "Intro Cutscene"
	# For this prototype, we'll jump straight to a Dungeon Run
	_start_dungeon_run()

func _on_continue_pressed():
	# 1. Load the file into memory
	if SaveSystem.load_game(1):
		# 2. Check where they are
		var location = SaveSystem.data.meta_data.location

		if SaveSystem.data.active_run != null:
			# They saved INSIDE a dungeon
			_resume_dungeon_run()
		else:
			# They saved in the HUB
			_load_hub_scene()

func _start_dungeon_run():
	RunManager.is_run_active = true
	# (Set up new seed in RunManager)
	get_tree().change_scene_to_packed(game_scene)

func _resume_dungeon_run():
	# Just load the scene. The Scene's _ready() will ask RunManager to restore.
	get_tree().change_scene_to_packed(game_scene)

func _load_hub_scene():
	pass
