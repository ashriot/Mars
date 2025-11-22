class_name HexChip
extends Control

signal chip_clicked(chip: HexChip)

enum ChipState { EMPTY, OCCUPIED }

# --- DATA ---
var grid_coords: Vector2i
var state: ChipState = ChipState.EMPTY
var current_piece: GamePiece = null

func setup(coords: Vector2i, size_px: Vector2):
	grid_coords = coords

	# Set the size of the Control to match the expected grid size
	custom_minimum_size = size_px
	size = size_px

	# Center the pivot so placement logic remains easy (center-based)
	pivot_offset = size / 2.0

	# Default tint
	modulate = Color(0.8, 0.8, 0.8, 1.0)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

		# --- CIRCULAR HITBOX HACK ---
		var center = size / 2.0
		var dist = event.position.distance_to(center)

		# Radius is half the width
		if dist > (size.x / 2.0):
			return

		chip_clicked.emit(self)
		accept_event()

func add_piece(piece_node: GamePiece):
	if state == ChipState.OCCUPIED:
		print("Slot occupied")
		return

	state = ChipState.OCCUPIED
	current_piece = piece_node

	add_child(piece_node)

	# Ensure the piece is centered exactly on the slot
	piece_node.position = Vector2.ZERO

func flip_piece():
	if current_piece:
		current_piece.flip_owner()
