extends Node
class_name Main

@export var hub_scene: PackedScene
@export var game_scene: PackedScene
@export var title_scene: PackedScene

# --- REFERENCES ---
@onready var world_layer = $WorldLayer
@onready var menu_layer = $MenuLayer
@onready var fader = $TransitionLayer/Fader

var current_instance: Node = null

func _ready():
	# Start logic
	load_title_screen()

func load_title_screen():
	await _fade_out()
	_change_content(title_scene, menu_layer) # Load into UI Layer

	# Connect signals
	if current_instance.has_signal("new_game_requested"):
		current_instance.new_game_requested.connect(load_hub)
	if current_instance.has_signal("continue_requested"):
		current_instance.continue_requested.connect(_on_continue_requested)

	_fade_in()

func load_hub():
	await _fade_out()
	_change_content(hub_scene, menu_layer) # Load into UI Layer

	current_instance.head_out.connect(start_dungeon_run)
	AudioManager.play_music("hub", 1.0)
	_fade_in()

func start_dungeon_run():
	await _fade_out()
	RunManager.is_run_active = false
	_change_content(game_scene, world_layer)

	current_instance.dungeon_exited.connect(return_to_hub_with_rewards)
	_fade_in()

func _on_continue_requested():
	if SaveSystem.data.active_run != null:
		# Resume Dungeon
		await _fade_out()

		RunManager.is_run_active = true

		_change_content(game_scene, world_layer) # Load into Node2D Layer

		current_instance.dungeon_exited.connect(return_to_hub_with_rewards)
		_fade_in()
	else:
		load_hub()

func _change_content(scene_packed: PackedScene, target_parent: Node):
	# 1. Cleanup old scene
	if current_instance:
		current_instance.queue_free()
		current_instance = null

	# 2. Instantiate new one
	current_instance = scene_packed.instantiate()

	# 3. Add to the correct layer
	target_parent.add_child(current_instance)

func _fade_out():
	fader.show()
	var tween = create_tween()
	tween.tween_property(fader, "modulate:a", 1.0, 0.5)
	await tween.finished

func _fade_in():
	var tween = create_tween()
	tween.tween_property(fader, "modulate:a", 0.0, 0.5)
	await tween.finished
	fader.hide()

func return_to_hub_with_rewards(_success: bool):
	await _fade_out()

	for hero in SaveSystem.party_roster:
		hero.injuries = 0

	RunManager.is_run_active = false
	SaveSystem.save_current_slot()

	_clear_current_scene()

	load_hub()

func _clear_current_scene():
	if current_instance:
		current_instance.queue_free()
		current_instance = null
