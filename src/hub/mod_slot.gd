extends Panel
class_name ModSlot

@onready var icon: TextureRect = $Icon
@onready var tier: Label = $Tier

var is_active: bool


func setup(mod, enable: bool):
	is_active = enable
	if not is_active:
		modulate.a = 0.1
	if mod:
		icon.texture = mod.icon
		tier.text = "+" + mod.tier
	else:
		icon.texture = null
		tier.text = ""
