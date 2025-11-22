class_name GamePiece
extends Control

# --- DATA ---
var unit_name: String = "Unknown"
var kernel_value: int = 0
var rank: int = 1
var rarity: int = 0
var protocol: int = 0

# 0:U, 1:UR, 2:DR, 3:D, 4:DL, 5:UL
var walls = [false, false, false, false, false, false]
var owner_id: int = 0
var is_face_down: bool = false

# --- VISUALS ---
@onready var icon = $Icon
@onready var label_kernel = $LabelKernel
@onready var background = $Background

@onready var wall_nodes = [
	$Wall_U,  $Wall_UR, $Wall_DR,
	$Wall_D,  $Wall_DL, $Wall_UL
]

func setup(data: Dictionary, player: int, size_px: Vector2):
	custom_minimum_size = size_px
	size = size_px
	pivot_offset = size / 2.0
	owner_id = player

	# 1. Load Data
	unit_name = data.get("name", "Unknown")
	kernel_value = data.get("kernel", 0)
	rank = data.get("rank", 1)
	rarity = data.get("rarity", 0)
	protocol = data.get("protocol", 0)

	var w_data = data.get("walls", [])
	if w_data.size() == 6:
		walls = w_data

	# 2. Setup Icon
	icon.texture = data["texture"]

	# 3. Update Visuals
	_update_owner_color()
	_update_ui()

func set_face_down(face_down: bool):
	is_face_down = face_down

	# Toggle visibility of "Front" elements
	icon.visible = !is_face_down
	label_kernel.visible = !is_face_down

	# For walls, we only show them if they exist AND we are face up
	for i in range(6):
		if wall_nodes[i]:
			wall_nodes[i].visible = (!is_face_down and walls[i])

func flip_owner():
	owner_id = 1 - owner_id
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0, 1), 0.15)
	tween.tween_callback(_update_owner_color)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.15)

func _update_owner_color():
	if owner_id == 0:
		background.self_modulate = Color(0.2, 0.8, 1.0) # Blue
	else:
		background.self_modulate = Color(1.0, 0.4, 0.2) # Red

func _update_ui():
	label_kernel.text = "%X" % kernel_value

	# Re-run face down logic to ensure walls state is correct
	set_face_down(is_face_down)
