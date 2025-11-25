extends Panel
class_name HeroStatus

@onready var role_name: Label = $RoleName
@onready var hero_name: Label = $HeroName
@onready var injuries: HBoxContainer = $Injuries
@onready var focused_boon: TextureRect = $Boons/Focused
@onready var armored_boon: TextureRect = $Boons/Armored

var active_color = Color(0.118, 0.118, 0.118, 1.0)
var inactive_color = Color(0.0, 0.0, 0.0, 0.588)

var panel_color: Color
var is_focused: bool :
	set(value):
		focused_boon.modulate.a = 1.0 if value else 0.25
		is_focused = value
var is_armored: bool :
	set(value):
		armored_boon.modulate.a = 1.0 if value else 0.25
		is_armored = value

var linked_hero_data: HeroData

func setup(data: HeroData):
	linked_hero_data = data
	refresh_view()

func refresh_view():
	if not linked_hero_data: return

	role_name.text = linked_hero_data.current_role.role_id.to_upper()
	hero_name.text = linked_hero_data.hero_name.to_upper()
	self.self_modulate = linked_hero_data.current_role.color

	# 1. Update Boons
	focused_boon.modulate = active_color if linked_hero_data.boon_focused else inactive_color
	armored_boon.modulate = active_color if linked_hero_data.boon_armored else inactive_color

	# 2. Update Injuries (Max 3 icons assumed in the HBox)
	# 0 injuries = All Dim
	# 1 injury = 1 Bright, 2 Dim
	var count = linked_hero_data.injuries
	for i in range(injuries.get_child_count()):
		var icon = injuries.get_child(i) as Control
		if i < count:
			icon.modulate = active_color
		else:
			icon.modulate= inactive_color
