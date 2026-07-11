extends Control
class_name Hub

signal head_out

@export var dungeon_profile: DungeonProfile
@export var party_menu: PartyMenu

@onready var bits_label: Label = $UI/BitsLabel
@onready var head_out_button: Button = $Actions/HeadOut


func _ready():
	bits_label.text = "BITS: %d" % SaveSystem.bits

func _on_head_out_pressed() -> void:
	RunManager.current_dungeon_tier = 1
	RunManager.dungeon_profile = dungeon_profile

	# Option B: Based on Story Progress (from SaveSystem)
	# e.g. If you are on Chapter 2, set tier to 2.
	# RunManager.current_dungeon_tier = SaveSystem.data.meta_data.chapter

	# Option C: Selected from UI (if you have a difficulty dropdown)
	# RunManager.current_dungeon_tier = $MissionSelect.get_selected_tier()

	head_out.emit()


func _on_button_3_pressed() -> void:
	party_menu.open()
