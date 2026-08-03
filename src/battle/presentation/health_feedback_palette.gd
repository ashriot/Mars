extends RefCounted
class_name HealthFeedbackPalette

enum Direction { DAMAGE, HEALING }

const DAMAGE_YELLOW := Color(0.98, 0.76766664, 0.0, 1.0)
const HEALING_GREEN := Color(0.20, 0.90, 0.45, 1.0)


static func apply(bar: ProgressBar, direction: Direction) -> void:
	var source := bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	assert(source != null, "Health feedback requires a StyleBoxFlat fill.")
	var style := source.duplicate() as StyleBoxFlat
	var color := DAMAGE_YELLOW if direction == Direction.DAMAGE else HEALING_GREEN
	style.bg_color = color
	style.border_color = color
	bar.add_theme_stylebox_override(&"fill", style)
