extends Node
class_name CombatPresentationSettingsService

signal shake_intensity_changed(value: float)

const DEFAULT_SHAKE_INTENSITY := 0.35
const SECTION := "combat_presentation"
const KEY := "shake_intensity"

var shake_intensity := DEFAULT_SHAKE_INTENSITY
var _storage_path := "user://presentation_settings.cfg"


func _ready() -> void:
	load_settings()


func set_shake_intensity(value: float, persist := true) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(shake_intensity, clamped):
		return
	shake_intensity = clamped
	shake_intensity_changed.emit(shake_intensity)
	if persist:
		_save_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(_storage_path) == OK:
		shake_intensity = clampf(
			float(config.get_value(SECTION, KEY, DEFAULT_SHAKE_INTENSITY)),
			0.0,
			1.0,
		)


func configure_storage_path_for_tests(path: String) -> void:
	_storage_path = path


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, KEY, shake_intensity)
	config.save(_storage_path)
