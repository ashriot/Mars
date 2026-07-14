extends TextureRect
class_name NavigationCursor

const POINTER_TEXTURE := preload("res://assets/graphics/glyphs/cursors/outline/pointer_c.svg")

# Temporary Task 5 compatibility surface. Ordinary battle and hub callers still
# compile against these names, but none of them can position or reveal this pointer.
enum CursorState { DEFAULT, INTERACT, CAN_GRAB, DRAGGING, UPGRADE, DISABLED, BUSY, TARGET, MODIFY }

var _target: CanvasItem
var _state := CursorState.DEFAULT


func _ready() -> void:
	texture = POINTER_TEXTURE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func show_at_screen_position(screen_position: Vector2) -> void:
	_target = null
	_state = CursorState.DEFAULT
	position = screen_position
	show()


func hide_pointer() -> void:
	hide()


# Remove these compatibility methods with the remaining Task 5 callers.
func set_focus_target(control: Control, state: CursorState = CursorState.DEFAULT) -> void:
	_target = control
	_state = state
	hide_pointer()


func set_world_target(canvas_item: CanvasItem, state: CursorState = CursorState.TARGET) -> void:
	_target = canvas_item
	_state = state
	hide_pointer()


func clear_target() -> void:
	_target = null
	_state = CursorState.DEFAULT
	hide_pointer()


func set_cursor_state(state: CursorState) -> void:
	_state = state
	hide_pointer()


func update_position_for_behavior(
	_behavior: InputManager.CursorBehavior,
	_mouse_position: Vector2,
	_immediate := false,
) -> void:
	hide_pointer()
