extends GutTest

var _settings: CombatPresentationSettingsService
var _storage_path: String


func before_each() -> void:
	_storage_path = "user://test-combat-settings-%s.cfg" % get_instance_id()
	_settings = CombatPresentationSettingsService.new()
	_settings.configure_storage_path_for_tests(_storage_path)


func after_each() -> void:
	if FileAccess.file_exists(_storage_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_storage_path))
	_settings.free()


func test_intensity_clamps_and_emits_normalized_value() -> void:
	watch_signals(_settings)
	_settings.set_shake_intensity(1.7, false)
	assert_eq(_settings.shake_intensity, 1.0)
	assert_signal_emitted_with_parameters(
		_settings, "shake_intensity_changed", [1.0],
	)


func test_zero_persists_and_reloads_as_off() -> void:
	_settings.set_shake_intensity(0.0)
	var restored := CombatPresentationSettingsService.new()
	restored.configure_storage_path_for_tests(_storage_path)
	restored.load_settings()
	assert_eq(restored.shake_intensity, 0.0)
	restored.free()
