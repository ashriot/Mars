class_name MapNode
extends Area2D

signal node_clicked(node: MapNode)

enum NodeType { COMBAT, ELITE, BOSS, REWARD, EVENT, UNKNOWN }
enum NodeState { HIDDEN, REVEALED, COMPLETED }

@onready var hex_sprite = $HexSprite
@onready var icon_sprite = $HexSprite/IconSprite

# --- VISUAL ASSETS ---
# Note: Hex and Selection textures are now set directly on the Sprites in the Scene!

@export_group("Event Icons")
@export var icon_combat: Texture2D
@export var icon_elite: Texture2D
@export var icon_boss: Texture2D
@export var icon_reward: Texture2D
@export var icon_event: Texture2D

# --- State ---
var type: NodeType = NodeType.UNKNOWN
var state: NodeState = NodeState.HIDDEN
var grid_coords: Vector2i

func setup(coords: Vector2i, hex_points: PackedVector2Array, assigned_type: NodeType):
	grid_coords = coords
	type = assigned_type

	var tex = _get_my_texture()
	icon_sprite.texture = tex
	icon_sprite.visible = false

	# 2. Create Hitbox (Calculated by Code)
	# We still create this in code to ensure the click area matches
	# the mathematical grid spacing exactly, regardless of sprite size.
	var coll = CollisionPolygon2D.new()
	coll.polygon = hex_points
	add_child(coll)

	# 3. Label (Optional)
	if has_node("Label"):
		$Label.text = "%d,%d" % [coords.x, coords.y]

	# 4. Initial State
	set_state(NodeState.HIDDEN)
	set_is_current(false)

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		node_clicked.emit(self)

func set_state(new_state: NodeState):
	state = new_state

	match state:
		NodeState.HIDDEN:
			hex_sprite.modulate = Color.SLATE_GRAY
			if icon_sprite: icon_sprite.visible = false
			hex_sprite.modulate.a = 0.5

		NodeState.REVEALED:
			if icon_sprite: icon_sprite.visible = true
			_set_type_color()
			# Darken slightly to show it's not visited yet
			hex_sprite.modulate.a = 1.0

		NodeState.COMPLETED:
			if icon_sprite: icon_sprite.visible = true
			_set_type_color()
			# Full brightness
			hex_sprite.modulate = hex_sprite.modulate.lightened(0.75)

func set_is_current(is_current: bool):
	$SelectionSprite.visible = is_current

func _set_type_color():
	match type:
		NodeType.COMBAT: hex_sprite.self_modulate = Color.GOLD
		NodeType.ELITE: hex_sprite.self_modulate = Color.ORANGE_RED
		NodeType.BOSS: hex_sprite.self_modulate = Color.MAGENTA
		NodeType.REWARD: hex_sprite.self_modulate = Color.CYAN
		NodeType.EVENT: hex_sprite.self_modulate = Color.LAWN_GREEN
		NodeType.UNKNOWN: hex_sprite.self_modulate = Color.WHITE

func _get_my_texture() -> Texture2D:
	match type:
		NodeType.COMBAT: return icon_combat
		NodeType.ELITE: return icon_elite
		NodeType.BOSS: return icon_boss
		NodeType.REWARD: return icon_reward
		NodeType.EVENT: return icon_event
	return null
