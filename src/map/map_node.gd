class_name MapNode
extends Area2D

signal node_clicked(node: MapNode)

enum NodeType { COMBAT, ELITE, BOSS, REWARD, REWARD_2, REWARD_3, EVENT, TERMINAL, UNKNOWN }
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
@export var icon_terminal: Texture2D

# --- State ---
var type: NodeType = NodeType.UNKNOWN
var state: NodeState = NodeState.HIDDEN
var has_been_visited: bool = false
var grid_coords: Vector2i

func setup(coords: Vector2i, assigned_type: NodeType):
	grid_coords = coords
	type = assigned_type

	var tex = _get_my_texture()
	icon_sprite.texture = tex
	icon_sprite.visible = false
	icon_sprite.modulate = Color(0.196, 0.196, 0.196, 1.0)

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
			hex_sprite.self_modulate = Color.BLACK
			if icon_sprite: icon_sprite.visible = false
			hex_sprite.modulate.a = 0.75

		NodeState.REVEALED:
			if icon_sprite: icon_sprite.visible = true
			_set_type_color()
			hex_sprite.modulate.a = 1.0

		NodeState.COMPLETED:
			if icon_sprite: icon_sprite.visible = true
			_set_type_color()
			icon_sprite.modulate.a = 0.25

func set_is_current(is_current: bool):
	$SelectionSprite.visible = is_current

func _set_type_color():
	match type:
		NodeType.COMBAT: hex_sprite.self_modulate = Color.YELLOW
		NodeType.ELITE: hex_sprite.self_modulate = Color.INDIAN_RED
		NodeType.BOSS: hex_sprite.self_modulate = Color.MAGENTA
		NodeType.REWARD: hex_sprite.self_modulate = Color.YELLOW_GREEN
		NodeType.REWARD_2: hex_sprite.self_modulate = Color.CADET_BLUE
		NodeType.REWARD_3: hex_sprite.self_modulate = Color.MEDIUM_PURPLE
		NodeType.EVENT: hex_sprite.self_modulate = Color.HOT_PINK
		NodeType.TERMINAL: hex_sprite.self_modulate = Color(1.0, 0.474, 0.17, 1.0)
		NodeType.UNKNOWN: hex_sprite.self_modulate = Color.DIM_GRAY

func _get_my_texture() -> Texture2D:
	match type:
		NodeType.COMBAT: return icon_combat
		NodeType.ELITE: return icon_elite
		NodeType.BOSS: return icon_boss
		NodeType.REWARD, NodeType.REWARD_2, NodeType.REWARD_3: return icon_reward
		NodeType.EVENT: return icon_event
		NodeType.TERMINAL: return icon_terminal
	return null
