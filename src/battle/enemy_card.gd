extends ActorCard
class_name EnemyCard

# --- UNIQUE Signals ---
signal enemy_clicked(enemy_card)

# --- UNIQUE Data ---
var enemy_data: EnemyData
var ai_index: int = 0

# --- UNIQUE UI Node References ---
@onready var intent_icon: TextureRect = $IntentIcon
@onready var name_label: Label = $NameLabel


func setup(data: EnemyData):
	self.enemy_data = data
	# --- Call the PARENT's setup function ---
	setup_base(data.stats)

	name_label.text = enemy_data.stats.actor_name
	if enemy_data.portrait:
		portrait_rect.texture = enemy_data.portrait

	add_to_group("enemy")

func _ready():
	self.gui_input.connect(_on_gui_input)

func get_next_action() -> Action:
	return
	var script = enemy_data.ai_script_indices
	var ability_index = script[ai_index]
	var next_action = enemy_data.action_deck[ability_index]

	ai_index = (ai_index + 1) % script.size() # Loop AI
	return next_action

func show_intent(icon: Texture):
	intent_icon.texture = icon
	intent_icon.visible = true

func hide_intent():
	intent_icon.visible = false

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		enemy_clicked.emit(self)
		get_viewport().set_input_as_handled()
