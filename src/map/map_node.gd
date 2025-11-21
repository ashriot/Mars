class_name MapNode
extends Area2D

# Signal to request a move to this node
signal node_clicked(node: MapNode)

enum NodeType { COMBAT, ELITE, BOSS, REWARD, EVENT, UNKNOWN }
enum NodeState { HIDDEN, REVEALED, COMPLETED }

# --- VISUAL ASSETS ---
@export_group("Event Icons")
@export var icon_combat: Texture2D
@export var icon_elite: Texture2D
@export var icon_boss: Texture2D
@export var icon_reward: Texture2D
@export var icon_event: Texture2D

# --- State Variables ---
var type: NodeType = NodeType.UNKNOWN
var state: NodeState = NodeState.HIDDEN
var grid_coords: Vector2i

# --- Visual References ---
var _poly: Polygon2D
var _icon_sprite: Sprite2D
var _label: Label

# --- Setup Function ---
func setup(coords: Vector2i, hex_points: PackedVector2Array, assigned_type: NodeType):
	grid_coords = coords
	type = assigned_type

	# 1. Visual Hex
	_poly = Polygon2D.new()
	_poly.polygon = hex_points
	_poly.color = Color.SLATE_GRAY
	add_child(_poly)

	# 2. Icon Sprite
	_icon_sprite = Sprite2D.new()
	_icon_sprite.visible = false

	# Resolve texture based on our own exports
	var tex = _get_my_texture()
	_icon_sprite.texture = tex

	if tex:
		var hex_radius = 50.0
		var icon_size = max(tex.get_width(), tex.get_height())
		if icon_size > 0:
			var scale_factor = (hex_radius * 1.2) / icon_size
			_icon_sprite.scale = Vector2(scale_factor, scale_factor)

	add_child(_icon_sprite)

	# 3. Click Hitbox
	var coll = CollisionPolygon2D.new()
	coll.polygon = hex_points
	add_child(coll)

	# 4. Debug Label
	_label = Label.new()
	#_label.text = "%d,%d" % [coords.x, coords.y]
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(-50, -25)
	_label.size = Vector2(100, 50)
	add_child(_label)

# --- Input Handling (Virtual Function) ---
# Godot calls this automatically for Area2D. No manual connection needed.
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		node_clicked.emit(self)

# --- State Management ---
func set_state(new_state: NodeState):
	state = new_state

	match state:
		NodeState.HIDDEN:
			_poly.color = Color.SLATE_GRAY
			_icon_sprite.visible = false

		NodeState.REVEALED:
			_icon_sprite.visible = true
			_set_type_color()
			_poly.color = _poly.color.darkened(0.6)

		NodeState.COMPLETED:
			_icon_sprite.visible = true
			_set_type_color()
			_poly.color = _poly.color.lightened(0.1)

func _set_type_color():
	match type:
		NodeType.COMBAT: _poly.color = Color.INDIAN_RED
		NodeType.ELITE: _poly.color = Color.DARK_RED
		NodeType.BOSS: _poly.color = Color.MAGENTA
		NodeType.REWARD: _poly.color = Color.GOLDENROD
		NodeType.EVENT: _poly.color = Color.CORNFLOWER_BLUE
		NodeType.UNKNOWN: _poly.color = Color.WHITE

func _get_my_texture() -> Texture2D:
	match type:
		NodeType.COMBAT: return icon_combat
		NodeType.ELITE: return icon_elite
		NodeType.BOSS: return icon_boss
		NodeType.REWARD: return icon_reward
		NodeType.EVENT: return icon_event
	return null
