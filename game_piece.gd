class_name GamePiece
extends Control

enum Abbr { C, UC, R, VR, U }

signal piece_selected(piece: GamePiece)

# --- DATA ---
var unit_name: String = "Unknown"
var base_kernel: int = 0 # Store the original value
var kernel_value: int = 0 # Current value
var rank: int = 1
var rarity: int = 0
var protocol: int = 0

# 0:U, 1:UR, 2:DR, 3:D, 4:DL, 5:UL
var walls = [false, false, false, false, false, false]
var owner_id: int = 0
var original_owner_id: int = 0
var is_face_down: bool = false

# --- VISUALS ---
@onready var icon = $Icon
@onready var face = $Face
@onready var kernel_label = $Face/KernelLabel
@onready var rarity_label = $Face/RarityLabel
@onready var protocol_label = $Face/ProtocolLabel
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
	original_owner_id = player

	# 1. Load Data
	unit_name = data.get("name", "Unknown")
	base_kernel = data.get("kernel", 0)
	kernel_value = base_kernel # Initialize current

	rank = data.get("rank", 1)
	rarity = data.get("rarity", 0)
	protocol = data.get("protocol", 0)

	var w_data = data.get("walls", [])
	if w_data.size() == 6:
		walls = w_data

	#icon.texture = data["texture"]

	_update_owner_color()
	_update_ui()

# --- NEW: Modifier for Protocols ---
func modify_kernel(amount: int):
	kernel_value += amount
	kernel_value = max(0, kernel_value) # Prevent negatives
	_update_ui()

	# Visual Pop for stat change
	var tween = create_tween()
	kernel_label.scale = Vector2(1.5, 1.5)
	kernel_label.modulate = Color.GREEN if amount > 0 else Color.RED
	tween.tween_property(kernel_label, "scale", Vector2.ONE, 0.3)
	tween.parallel().tween_property(kernel_label, "modulate", Color.WHITE, 0.3)

# --- INPUT HANDLING ---
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not is_face_down:
				piece_selected.emit(self)

func _get_drag_data(_at_position):
	if is_face_down: return null
	var preview = self.duplicate()
	preview.modulate.a = 0.8
	preview.scale = Vector2(0.8, 0.8)
	preview.set_rotation(0)
	var c = Control.new()
	c.add_child(preview)
	preview.position = -size / 2.0 * 0.8
	set_drag_preview(c)
	return self

# --- VISUAL STATES ---
func set_selected(is_selected: bool):
	var target_scale = Vector2(1.1, 1.1) if is_selected else Vector2(1.0, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.1)

	if has_node("SelectionBorder"):
		get_node("SelectionBorder").visible = is_selected

func set_face_down(face_down: bool):
	is_face_down = face_down
	face.visible = !is_face_down

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
		background.self_modulate = Color(0.2, 0.8, 1.0)
	else:
		background.self_modulate = Color(1.0, 0.4, 0.2)

func _update_ui():
	# Display Hex if > 9
	kernel_label.text = "%X" % kernel_value
	rarity_label.text = Abbr.keys()[rarity]
	if ChipLibrary.Protocol.keys()[protocol] != "NONE":
		protocol_label.text = ChipLibrary.Protocol.keys()[protocol]
	else:
		protocol_label.text = ""
	tooltip_text = ChipLibrary.PROTO_DESC.get(protocol, "No Effect")
	set_face_down(is_face_down)
