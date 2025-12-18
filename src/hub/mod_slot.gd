extends Panel
class_name ModSlot

signal clicked

@onready var icon: TextureRect = $Icon
@onready var tier: Label = $Tier
@onready var plus: Label = $Plus
@onready var button: BaseButton = $Button # Assuming you have a button overlay

var is_active: bool
var _pulse_tween: Tween


func setup(mod: EquipmentMod, enable: bool):
	is_active = enable

	if is_active:
		self.modulate.a = 1.0
		button.disabled = false
		plus.visible = (mod == null)
	else:
		self.modulate.a = 0.1
		button.disabled = true
		plus.visible = false

	if mod:
		icon.texture = mod.icon
		tier.text = str(mod.tier) if "tier" in mod else ""
	else:
		icon.texture = null
		tier.text = ""

func pulse(color: Color):
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	self.self_modulate = Color.WHITE

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_pulse_tween.tween_property(self, "self_modulate", color, 0.5)
	_pulse_tween.tween_property(self, "self_modulate", Color.WHITE, 0.5)

func stop_pulse():
	if _pulse_tween:
		_pulse_tween.kill()
	self.self_modulate = Color.WHITE

func _on_button_pressed() -> void:
	clicked.emit()
