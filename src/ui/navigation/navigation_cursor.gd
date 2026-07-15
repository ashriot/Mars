extends TextureRect
class_name NavigationCursor

const POINTER_TEXTURE := preload("res://assets/graphics/glyphs/cursors/outline/pointer_c.svg")

func _ready() -> void:
	texture = POINTER_TEXTURE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_at_screen_position(screen_position: Vector2) -> void:
	position = screen_position
	show()


func hide_pointer() -> void:
	hide()
