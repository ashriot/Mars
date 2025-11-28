# TooltipManager.gd (Autoload)
extends CanvasLayer

# Path to your scene
const TOOLTIP_SCENE_PATH = "res://src/core/tooltip_panel.tscn"

var _tooltip_instance: Control = null
var _timer: Timer

func _ready():
	# 1. Set Layer to Max so it's always on top
	layer = 128

	# 2. Instantiate the tooltip immediately but hide it
	var scene = load(TOOLTIP_SCENE_PATH)
	if scene:
		_tooltip_instance = scene.instantiate()
		add_child(_tooltip_instance)
		_tooltip_instance.hide()

	# 3. Create a delay timer (prevents flickering)
	_timer = Timer.new()
	_timer.wait_time = 0.3 # Delay before showing
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

func _process(_delta):
	if _tooltip_instance and _tooltip_instance.visible:
		_update_position()

# --- PUBLIC API ---

func request_tooltip(text: String):
	if not _tooltip_instance: return

	# Set text immediately
	if _tooltip_instance.has_method("set_text"):
		_tooltip_instance.set_text(text)

	# Start timer
	_timer.start()

func hide_tooltip():
	_timer.stop()
	if _tooltip_instance:
		_tooltip_instance.hide()

# --- INTERNAL ---

func _on_timer_timeout():
	if _tooltip_instance:
		_tooltip_instance.show()
		_update_position()

# In TooltipManager.gd

func _update_position():
	if not _tooltip_instance: return

	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	var tip_size = _tooltip_instance.size

	var offset_y = 30.0

	var target_pos = Vector2(
		mouse_pos.x - (tip_size.x / 2.0),
		mouse_pos.y - tip_size.y - offset_y
	)

	# A. Vertical Clamp (Flip down if hitting top)
	if target_pos.y < 0:
		target_pos.y = mouse_pos.y + offset_y

	if target_pos.x < 0:
		target_pos.x = 0
	elif target_pos.x + tip_size.x > screen_size.x:
		target_pos.x = screen_size.x - tip_size.x

	_tooltip_instance.position = target_pos
