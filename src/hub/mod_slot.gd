extends Panel
class_name ModSlot

signal clicked

@onready var icon: TextureRect = $Icon
@onready var tier: Label = $Tier
@onready var plus: Label = $Plus
@onready var button: BaseButton = $Button # Assuming you have a button overlay
@onready var selection_outline: Panel = $SelectionOutline

var is_active: bool
var _pulse_tween: Tween


func _ready() -> void:
	button.set_meta("navigation_focus_surface", NodePath(".."))
	button.set_meta("navigation_focus_pulse", true)
	HubChrome.capture(self)
	DisplayProfile.bind(apply_display_profile)


func apply_display_profile(profile: int, _window_size: Vector2i, _logical_size: Vector2) -> void:
	custom_minimum_size = Vector2(72.0, 72.0) if profile == DisplayProfileService.Profile.COMPACT else Vector2(64.0, 64.0)


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
	button.focus_mode = Control.FOCUS_ALL if enable else Control.FOCUS_NONE

	if mod:
		icon.texture = mod.icon
		tier.text = str(mod.tier) if "tier" in mod else ""
	else:
		icon.texture = null
		tier.text = ""

func pulse(color: Color):
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	selection_outline.modulate = Color(color.r, color.g, color.b, 0.35)

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_pulse_tween.tween_property(selection_outline, "modulate:a", 1.0, 0.5)
	_pulse_tween.tween_property(selection_outline, "modulate:a", 0.35, 0.5)

func stop_pulse():
	if _pulse_tween:
		_pulse_tween.kill()
	selection_outline.modulate = Color(1, 1, 1, 0)

func _on_button_pressed() -> void:
	clicked.emit()


func get_focus_control() -> BaseButton:
	return button


func set_chrome_active(active: bool) -> void:
	HubChrome.set_active(self, active)
