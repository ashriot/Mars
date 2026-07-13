extends Node

enum ControllerType {
	KEYBOARD_MOUSE,
	XBOX,
	PLAYSTATION,
	NINTENDO_SWITCH,
	NINTENDO_SWITCH_2,
	STEAM_CONTROLLER,
	STEAM_DECK,
}

const FAMILY_FOLDERS := {
	ControllerType.KEYBOARD_MOUSE: "keyboard_mouse",
	ControllerType.XBOX: "xbox",
	ControllerType.PLAYSTATION: "playstation",
	ControllerType.NINTENDO_SWITCH: "nintendo_switch",
	ControllerType.NINTENDO_SWITCH_2: "nintendo_switch_2",
	ControllerType.STEAM_CONTROLLER: "steam_controller",
	ControllerType.STEAM_DECK: "steam_deck",
}

const GLYPH_FILES := {
	ControllerType.KEYBOARD_MOUSE: {
		&"confirm": "keyboard_enter.svg", &"cancel": "keyboard_escape.svg",
		&"action_1": "keyboard_1.svg", &"action_2": "keyboard_2.svg",
		&"action_3": "keyboard_3.svg", &"action_4": "keyboard_4.svg",
		&"shift_action": "keyboard_shift.svg",
	},
	ControllerType.XBOX: {
		&"confirm": "xbox_button_a.svg", &"cancel": "xbox_button_b.svg",
		&"action_1": "xbox_button_a.svg", &"action_2": "xbox_button_b.svg",
		&"action_3": "xbox_button_x.svg", &"action_4": "xbox_button_y.svg",
		&"shift_action": "xbox_lt.svg",
	},
	ControllerType.PLAYSTATION: {
		&"confirm": "playstation_button_cross.svg", &"cancel": "playstation_button_circle.svg",
		&"action_1": "playstation_button_cross.svg", &"action_2": "playstation_button_circle.svg",
		&"action_3": "playstation_button_square.svg", &"action_4": "playstation_button_triangle.svg",
		&"shift_action": "playstation_trigger_l2.svg",
	},
	ControllerType.NINTENDO_SWITCH: {
		&"confirm": "switch_button_a.svg", &"cancel": "switch_button_b.svg",
		&"action_1": "switch_button_b.svg", &"action_2": "switch_button_a.svg",
		&"action_3": "switch_button_y.svg", &"action_4": "switch_button_x.svg",
		&"shift_action": "switch_button_zl.svg",
	},
	ControllerType.NINTENDO_SWITCH_2: {
		&"confirm": "switch_button_a.svg", &"cancel": "switch_button_b.svg",
		&"action_1": "switch_button_b.svg", &"action_2": "switch_button_a.svg",
		&"action_3": "switch_button_y.svg", &"action_4": "switch_button_x.svg",
		&"shift_action": "switch_button_zl.svg",
	},
	ControllerType.STEAM_CONTROLLER: {
		&"confirm": "steam_button_a.svg", &"cancel": "steam_button_b.svg",
		&"action_1": "steam_button_a.svg", &"action_2": "steam_button_b.svg",
		&"action_3": "steam_button_x.svg", &"action_4": "steam_button_y.svg",
		&"shift_action": "controller_button_l2.svg",
	},
	ControllerType.STEAM_DECK: {
		&"confirm": "steamdeck_button_a.svg", &"cancel": "steamdeck_button_b.svg",
		&"action_1": "steamdeck_button_a.svg", &"action_2": "steamdeck_button_b.svg",
		&"action_3": "steamdeck_button_x.svg", &"action_4": "steamdeck_button_y.svg",
		&"shift_action": "steamdeck_button_l2.svg",
	},
}

func runtime_controller_types() -> Array[ControllerType]:
	return [
		ControllerType.KEYBOARD_MOUSE,
		ControllerType.XBOX,
		ControllerType.PLAYSTATION,
		ControllerType.NINTENDO_SWITCH,
		ControllerType.NINTENDO_SWITCH_2,
		ControllerType.STEAM_CONTROLLER,
		ControllerType.STEAM_DECK,
	]


func normalize_controller_type(type: ControllerType) -> ControllerType:
	return type if FAMILY_FOLDERS.has(type) else ControllerType.STEAM_DECK


func confirm_cancel_buttons(type: ControllerType) -> Dictionary:
	var resolved := normalize_controller_type(type)
	if resolved in [ControllerType.NINTENDO_SWITCH, ControllerType.NINTENDO_SWITCH_2]:
		return {&"confirm": JOY_BUTTON_B, &"cancel": JOY_BUTTON_A}
	return {&"confirm": JOY_BUTTON_A, &"cancel": JOY_BUTTON_B}


func get_controller_type_from_name(controller_name: String) -> ControllerType:
	var lower_name := controller_name.to_lower()
	if "nintendo switch 2" in lower_name or "switch 2" in lower_name:
		return ControllerType.NINTENDO_SWITCH_2
	if "nintendo" in lower_name or "switch" in lower_name or "joy-con" in lower_name:
		return ControllerType.NINTENDO_SWITCH
	if "playstation" in lower_name or "dualshock" in lower_name or "dualsense" in lower_name:
		return ControllerType.PLAYSTATION
	if "steam controller" in lower_name:
		return ControllerType.STEAM_CONTROLLER
	if "steam deck" in lower_name or "steam virtual" in lower_name:
		return ControllerType.STEAM_DECK
	if "xbox" in lower_name or "xinput" in lower_name:
		return ControllerType.XBOX
	return ControllerType.STEAM_DECK


func get_glyph_path(type: ControllerType, action: StringName) -> String:
	var resolved_type := normalize_controller_type(type)
	var family: Dictionary = GLYPH_FILES[resolved_type]
	var file_name: String = family.get(action, "")
	if file_name.is_empty():
		return ""
	return "res://assets/graphics/glyphs/%s/vector/%s" % [FAMILY_FOLDERS[resolved_type], file_name]


func get_glyph(type: ControllerType, action: StringName) -> Texture2D:
	var path := get_glyph_path(type, action)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
