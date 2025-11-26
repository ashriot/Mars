extends Panel
class_name HeroStatus

@onready var role_ui: Control = $Role
@onready var box: Control = $Role/Window/HBox
@onready var role_name: Label = $Role/Window/HBox/Name
@onready var next_role_name: Label = $Role/Window/HBox/Next
@onready var prev_role_name: Label = $Role/Window/HBox/Prev
@onready var hero_name: Label = $HeroName
@onready var injuries: HBoxContainer = $Injuries
@onready var focused_boon: TextureRect = $Boons/Focused
@onready var armored_boon: TextureRect = $Boons/Armored

var busy := false
var anim_time := 0.3
var label_width := 0

var active_color = Color(0.118, 0.118, 0.118, 1.0)
var inactive_color = Color(0.212, 0.212, 0.212, 0.686)

var linked_hero_data: HeroData

func _ready():
	label_width = int(role_name.size.x)
	_reset_positions()

func setup(data: HeroData):
	linked_hero_data = data
	refresh_view()

func refresh_view():
	if not linked_hero_data:
		return

	var defs = linked_hero_data.role_definitions
	var idx = linked_hero_data.active_role_index

	var prev_idx = (idx - 1 + defs.size()) % defs.size()
	var next_idx = (idx + 1) % defs.size()

	prev_role_name.text = defs[prev_idx].role_id
	role_name.text = defs[idx].role_id
	next_role_name.text = defs[next_idx].role_id

	hero_name.text = linked_hero_data.hero_name
	self.self_modulate = linked_hero_data.current_role.color

	focused_boon.modulate = active_color if linked_hero_data.boon_focused else inactive_color
	armored_boon.modulate = active_color if linked_hero_data.boon_armored else inactive_color

	var count = linked_hero_data.injuries
	for i in range(injuries.get_child_count()):
		var icon = injuries.get_child(i)
		icon.modulate = active_color if i < count else inactive_color

func _reset_positions():
	box.position.x = -63.0

func _slide(direction: int):
	if busy:
		return
	busy = true

	var defs = linked_hero_data.role_definitions
	var idx = linked_hero_data.active_role_index
	var incoming = 0
	if direction == 1:
		incoming = (idx + 1) % defs.size()
		next_role_name.text = defs[incoming].role_id
	else:
		incoming = (idx - 1 + defs.size()) % defs.size()
		prev_role_name.text = defs[incoming].role_id

	var tween := create_tween()

	tween.parallel().tween_property(box, "position:x",
			box.position.x - label_width * direction,
			anim_time)

	var new_color = defs[incoming].color
	tween.parallel().tween_property(self, "self_modulate",
			new_color, anim_time)

	tween.finished.connect(func():
		if direction == 1:
			linked_hero_data.active_role_index = (idx + 1) % defs.size()
		else:
			linked_hero_data.active_role_index = (idx - 1 + defs.size()) % defs.size()

		refresh_view()
		_reset_positions()
		busy = false
	)

func _on_left_pressed() -> void:
	_slide(-1)

func _on_right_pressed() -> void:
	_slide(+1)
