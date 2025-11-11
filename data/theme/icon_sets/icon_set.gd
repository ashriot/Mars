# IconSet.gd
extends Resource
class_name IconSet

@export var action_icons: Dictionary = {
	"ui_accept": null,        # Texture for (Cross / A)
	"ui_cancel": null,        # Texture for (Circle / B)
	"ui_action_left": null,   # Texture for (Square / X)
	"ui_action_up": null,     # Texture for (Triangle / Y)
	"ui_shift_left": null,    # Texture for (L2 / LT)
	"ui_shift_right": null,   # Texture for (R2 / RT)
	"ui_tooltip": null,       # Texture for (L1 / LB)
	"ui_inventory": null,     # Texture for (R1 / RB)
	"ui_target_next": null,   # Texture for (D-Pad Right)
	"ui_target_prev": null    # Texture for (D-Pad Left)
}
