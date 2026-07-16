extends Node
class_name DisplayProfileService

signal profile_changed(profile: int, window_size: Vector2i, logical_size: Vector2)

enum Profile { DESKTOP, COMPACT }

const REFERENCE_SIZE := Vector2(1920, 1080)
const DESKTOP_WINDOW_SIZE := Vector2i(1920, 1080)
const COMPACT_MAX_WIDTH := 1366
const COMPACT_MAX_HEIGHT := 800

var current_profile: int = Profile.DESKTOP
var window_size := DESKTOP_WINDOW_SIZE
var logical_size := REFERENCE_SIZE


func _ready() -> void:
	get_tree().root.size_changed.connect(refresh_from_display)
	_configure_startup_window()
	refresh_from_display()


static func profile_for(size: Vector2i) -> int:
	return Profile.COMPACT if size.x <= COMPACT_MAX_WIDTH or size.y <= COMPACT_MAX_HEIGHT else Profile.DESKTOP


static func startup_policy_for(screen_size: Vector2i) -> Dictionary:
	if profile_for(screen_size) == Profile.COMPACT:
		return {size = screen_size, mode = DisplayServer.WINDOW_MODE_FULLSCREEN}
	return {size = DESKTOP_WINDOW_SIZE, mode = DisplayServer.WINDOW_MODE_WINDOWED}


static func output_scale_for(size: Vector2i) -> float:
	return minf(float(size.x) / REFERENCE_SIZE.x, float(size.y) / REFERENCE_SIZE.y)


static func expanded_logical_size_for(size: Vector2i) -> Vector2:
	var scale := output_scale_for(size)
	return REFERENCE_SIZE if scale <= 0.0 else Vector2(size) / scale


static func safe_rect_for(available_size: Vector2) -> Rect2:
	var scale := minf(1.0, minf(available_size.x / REFERENCE_SIZE.x, available_size.y / REFERENCE_SIZE.y))
	var safe_size := REFERENCE_SIZE * scale
	return Rect2((available_size - safe_size) * 0.5, safe_size)


func update_metrics(next_window_size: Vector2i, next_logical_size: Vector2) -> bool:
	if next_window_size.x <= 0 or next_window_size.y <= 0 or next_logical_size.x <= 0.0 or next_logical_size.y <= 0.0:
		return false
	var next_profile := profile_for(next_window_size)
	if next_profile == current_profile and next_window_size == window_size and next_logical_size.is_equal_approx(logical_size):
		return false
	current_profile = next_profile
	window_size = next_window_size
	logical_size = next_logical_size
	profile_changed.emit(current_profile, window_size, logical_size)
	return true


func refresh_from_display() -> void:
	update_metrics(DisplayServer.window_get_size(), get_tree().root.get_visible_rect().size)


func bind(callback: Callable) -> void:
	if not profile_changed.is_connected(callback):
		profile_changed.connect(callback)
	callback.call(current_profile, window_size, logical_size)


func _configure_startup_window() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("editor"):
		return
	var policy := startup_policy_for(DisplayServer.screen_get_size())
	DisplayServer.window_set_mode(policy.mode)
	if policy.mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(policy.size)
