extends Control
class_name Hub

signal head_out

@export var dungeon_profile: DungeonProfile
@export var party_menu: PartyMenu

@onready var bits_label: Label = $UI/BitsLabel
@onready var head_out_button: Button = $Actions/HeadOut


func _ready():
	bits_label.text = "BITS: %d" % SaveSystem.bits
	for button in $Actions.get_children():
		if button is Button:
			button.focus_entered.connect(_publish_hints)
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.register_screen(self, head_out_button)
	_publish_hints()
	_grab_focus_if_valid.call_deferred(head_out_button)


func _exit_tree() -> void:
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.unregister_screen(self)

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


func _navigation_ux_layer() -> NavigationUXLayer:
	return get_tree().root.find_child("NavigationUXLayer", true, false) as NavigationUXLayer


func _publish_hints() -> void:
	var navigation := _navigation_ux_layer()
	if navigation:
		navigation.publish_hints([{action = &"confirm", label = "Select", enabled = true}])


func _grab_focus_if_valid(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and not (control is BaseButton and control.disabled):
		control.grab_focus()
