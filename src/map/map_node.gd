class_name MapNode
extends Area2D

# Signal to request a move to this node
signal node_clicked(node: MapNode)

enum NodeType { COMBAT, ELITE, BOSS, REWARD, EVENT, UNKNOWN }
enum NodeState { HIDDEN, REVEALED, COMPLETED }

# --- State Variables ---
var type: NodeType = NodeType.UNKNOWN
var state: NodeState = NodeState.HIDDEN
var grid_coords: Vector2i

# --- Visual References ---
var _poly: Polygon2D
var _icon_sprite: Sprite2D
var _label: Label

# --- Setup Function ---
func setup(coords: Vector2i, hex_points: PackedVector2Array, assigned_type: NodeType, icon_texture: Texture2D):
	grid_coords = coords
	type = assigned_type

	# 1. Visual Hex
	_poly = Polygon2D.new()
	_poly.polygon = hex_points
	_poly.color = Color.SLATE_GRAY # Default Hidden color
	add_child(_poly)

	# 2. Icon Sprite
	_icon_sprite = Sprite2D.new()
	_icon_sprite.texture = icon_texture
	_icon_sprite.visible = false # Hidden initially

	if icon_texture:
		var hex_radius = 50.0
		var icon_size = max(icon_texture.get_width(), icon_texture.get_height())
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
	# Optional: Hide label if hidden?
	# _label.visible = false
	add_child(_label)

	input_pickable = true
	input_event.connect(_on_input_event)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# We don't change state here anymore. We ask the MapGenerator.
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
			# Revealed but not visited might be slightly dimmed?
			_poly.color = _poly.color.darkened(0.5)

		NodeState.COMPLETED:
			_icon_sprite.visible = true
			_set_type_color()
			# Bright/Normal color to show we are here/done
			_poly.color = _poly.color.lightened(0.1)

func _set_type_color():
	match type:
		NodeType.COMBAT: _poly.color = Color.INDIAN_RED
		NodeType.ELITE: _poly.color = Color.DARK_RED
		NodeType.BOSS: _poly.color = Color.BLACK
		NodeType.REWARD: _poly.color = Color.GOLDENROD
		NodeType.EVENT: _poly.color = Color.CORNFLOWER_BLUE
		NodeType.UNKNOWN: _poly.color = Color.WHITE
