class_name GamePiece
extends Control

enum RarityAbbr { C, UC, R, VR, U }

signal piece_selected(piece: GamePiece)

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
@onready var kernel_label = $LabelKernel
@onready var rarity_label = $RarityLabel
@onready var background = $Background
# Helper for selection border (add a ReferenceRect or ColorRect named 'SelectionBorder' if you want visuals)
# For now we will just scale it up/down to show selection

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
	icon.texture = data["texture"]

	# 3. Update Visuals
	_update_owner_color()
	_update_ui()

# --- INPUT HANDLING (New) ---

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Don't allow selecting face-down cards (opponent's hand)
			if not is_face_down:
				piece_selected.emit(self)

func _get_drag_data(_at_position):
	if is_face_down: return null # Cannot drag enemy cards

	# visual preview
	var preview = self.duplicate()
	preview.modulate.a = 0.8
	preview.scale = Vector2(0.8, 0.8)
	preview.set_rotation(0) # Reset rotation if any

	# Center the preview on mouse
	var c = Control.new()
	c.add_child(preview)
	preview.position = -size / 2.0 * 0.8
	set_drag_preview(c)

	# Data passed to drop target
	return self

# --- VISUAL STATES ---

func set_selected(is_selected: bool):
	var target_scale = Vector2(1.1, 1.1) if is_selected else Vector2(1.0, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.1)

	# Optional: visual border toggle
	if has_node("SelectionBorder"):
		get_node("SelectionBorder").visible = is_selected

func set_face_down(face_down: bool):
	is_face_down = face_down

	icon.visible = !is_face_down
	kernel_label.visible = !is_face_down
	rarity_label.visible = !is_face_down

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
	kernel_label.text = "%X" % kernel_value
	rarity_label.text = RarityAbbr.keys()[rarity]
	set_face_down(is_face_down)
