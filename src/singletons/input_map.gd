# InputIconMap.gd
extends Node

# --- ENUM DEFINITIONS ---
enum ControllerType { UNKNOWN, XBOX, PS, SWITCH }

# Actions that match your Project Settings -> Input Map names
enum Action {
	SHIFT_LEFT, SHIFT_RIGHT,
	ACTION_1, ACTION_2, ACTION_3, ACTION_4,
	TARGET_UP, TARGET_DOWN, TARGET_LEFT, TARGET_RIGHT
}

# Dictionary structure: [ControllerType][Action][State (Normal/Pressed)] -> Texture2D
const GLYPHS = {
	ControllerType.PS: {
		# Action Glyphs (L2/R2)
		Action.SHIFT_LEFT:   { "normal": preload("res://assets/graphics/glyphs/ps/ps_L2_normal.png"),   "pressed": preload("res://assets/graphics/glyphs/ps/ps_L2_pressed.png") },
		Action.SHIFT_RIGHT:  { "normal": preload("res://assets/graphics/glyphs/ps/ps_R2_normal.png"),  "pressed": preload("res://assets/graphics/glyphs/ps/ps_R2_pressed.png") },
		# Face Button Glyphs (A/B/X/Y)
		Action.ACTION_1:     { "normal": preload("res://assets/graphics/glyphs/ps/ps_cross_normal.png"), "pressed": preload("res://assets/graphics/glyphs/ps/ps_cross_pressed.png") },
		Action.ACTION_2:     { "normal": preload("res://assets/graphics/glyphs/ps/ps_circle_normal.png"),"pressed": preload("res://assets/graphics/glyphs/ps/ps_circle_pressed.png") },
		Action.ACTION_3:     { "normal": preload("res://assets/graphics/glyphs/ps/ps_square_normal.png"),"pressed": preload("res://assets/graphics/glyphs/ps/ps_square_pressed.png") },
		Action.ACTION_4:     { "normal": preload("res://assets/graphics/glyphs/ps/ps_triangle_normal.png"),"pressed": preload("res://assets/graphics/glyphs/ps/ps_triangle_pressed.png") },
		# D-Pad Glyphs (Targeting)
		Action.TARGET_UP:    { "normal": preload("res://assets/graphics/glyphs/ps/ps_dpad_up_normal.png"),  "pressed": preload("res://assets/graphics/glyphs/ps/ps_dpad_up_pressed.png") },
		Action.TARGET_DOWN:  { "normal": preload("res://assets/graphics/glyphs/ps/ps_dpad_down_normal.png"), "pressed": preload("res://assets/graphics/glyphs/ps/ps_dpad_down_pressed.png") },
		Action.TARGET_LEFT:  { "normal": preload("res://assets/graphics/glyphs/ps/ps_dpad_left_normal.png"), "pressed": preload("res://assets/graphics/glyphs/ps/ps_dpad_left_pressed.png") },
		Action.TARGET_RIGHT: { "normal": preload("res://assets/graphics/glyphs/ps/ps_dpad_right_normal.png"),"pressed": preload("res://assets/graphics/glyphs/ps/ps_dpad_right_pressed.png") },
	},
	# Add your ControllerType.XBOX and ControllerType.SWITCH entries here
	ControllerType.XBOX: {
		# ... Fill in all 10 Xbox actions with normal/pressed textures ...
	},
	ControllerType.SWITCH: {
		# ... Fill in all 10 Switch actions with normal/pressed textures ...
	}
}

# --- HELPER FUNCTION ---

func get_controller_type_from_name(controller_name: String) -> ControllerType:
	var lower_name = controller_name.to_lower()
	if "xbox" in lower_name:
		return ControllerType.XBOX
	if "playstation" in lower_name or "dualshock" in lower_name or "dualsense" in lower_name:
		return ControllerType.PS
	if "nintendo" in lower_name:
		return ControllerType.SWITCH
	return ControllerType.UNKNOWN
