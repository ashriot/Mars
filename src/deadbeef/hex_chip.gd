class_name HexChip
extends Control

# Unified signal: dropped_piece is null for click, valid for drop
signal chip_interaction(chip: HexChip, dropped_piece: GamePiece)

enum ChipState { EMPTY, OCCUPIED }

# --- DATA ---
var grid_coords: Vector2i
var state: ChipState = ChipState.EMPTY
var current_piece: GamePiece = null

func setup(coords: Vector2i, size_px: Vector2):
	grid_coords = coords
	custom_minimum_size = size_px
	size = size_px
	pivot_offset = size / 2.0

	modulate = Color(0.8, 0.8, 0.8, 1.0)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

		var center = size / 2.0
		var dist = event.position.distance_to(center)
		if dist > (size.x / 2.0): return

		# Regular click (no drag data)
		chip_interaction.emit(self, null)
		accept_event()

# --- DRAG AND DROP SUPPORT ---

func _can_drop_data(_at_position, data):
	# Only allow drop if we are empty and the data is a GamePiece
	return state == ChipState.EMPTY and data is GamePiece

func _drop_data(_at_position, data):
	# Signal the manager that a specific piece was dropped here
	chip_interaction.emit(self, data)

# --- LOGIC ---

func add_piece(piece_node: GamePiece):
	if state == ChipState.OCCUPIED:
		print("Slot occupied")
		return

	state = ChipState.OCCUPIED
	current_piece = piece_node

	add_child(piece_node)

	# Reset transform so it snaps to center
	piece_node.position = Vector2.ZERO
	piece_node.scale = Vector2.ONE
	piece_node.rotation = 0

func flip_piece():
	if current_piece:
		current_piece.flip_owner()
