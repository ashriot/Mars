class_name MapNode
extends Area2D

signal node_clicked(node: MapNode)

enum NodeType { ENTRANCE, COMBAT, ELITE, BOSS, REWARD, REWARD_2, REWARD_3, EVENT, TERMINAL, EXIT, UNKNOWN }
enum NodeState { HIDDEN, REVEALED, COMPLETED }

@onready var hex_sprite = $HexSprite
@onready var icon_sprite = $HexSprite/IconSprite

@export_group("Event Icons")
@export var icon_entrance: Texture2D
@export var icon_combat: Texture2D
@export var icon_elite: Texture2D
@export var icon_boss: Texture2D
@export var icon_reward: Texture2D
@export var icon_reward_2: Texture2D
@export var icon_reward_3: Texture2D
@export var icon_event: Texture2D
@export var icon_terminal: Texture2D
@export var icon_exit: Texture2D

# --- State ---
var type: NodeType = NodeType.UNKNOWN
var state: NodeState = NodeState.HIDDEN
var grid_coords: Vector2i
var has_been_visited: bool = false:
	set(value):
		has_been_visited = value
		if value:
			hex_sprite.modulate = Color.DARK_GRAY


func _ready():
	if not hex_sprite:
		push_error("hex_sprite missing!")
	if has_been_visited:
		hex_sprite.modulate = Color.DARK_GRAY
	else:
		hex_sprite.modulate = Color.WHITE

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

func _set_type_color():
	match type:
		NodeType.ENTRANCE: hex_sprite.self_modulate = Color.WEB_GRAY
		NodeType.COMBAT: hex_sprite.self_modulate = Color.INDIAN_RED
		NodeType.ELITE: hex_sprite.self_modulate = Color.ORANGE_RED
		NodeType.BOSS: hex_sprite.self_modulate = Color.RED
		NodeType.REWARD: hex_sprite.self_modulate = Color.YELLOW_GREEN
		NodeType.REWARD_2: hex_sprite.self_modulate = Color.CADET_BLUE
		NodeType.REWARD_3: hex_sprite.self_modulate = Color.MEDIUM_PURPLE
		NodeType.EVENT: hex_sprite.self_modulate = Color.GOLDENROD
		NodeType.TERMINAL: hex_sprite.self_modulate = Color.ORANGE
		NodeType.EXIT: hex_sprite.self_modulate = Color.MAGENTA
		NodeType.UNKNOWN: hex_sprite.self_modulate = Color.DIM_GRAY

func _get_my_texture() -> Texture2D:
	match type:
		NodeType.ENTRANCE: return icon_entrance
		NodeType.COMBAT: return icon_combat
		NodeType.ELITE: return icon_elite
		NodeType.BOSS: return icon_boss
		NodeType.REWARD: return icon_reward
		NodeType.REWARD_2: return icon_reward_2
		NodeType.REWARD_3: return icon_reward_3
		NodeType.EVENT: return icon_event
		NodeType.EXIT: return icon_exit
		NodeType.TERMINAL: return icon_terminal
	return null
