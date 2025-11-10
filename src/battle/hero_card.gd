extends ActorCard
class_name HeroCard

# --- UNIQUE Signals ---
signal role_shifted(hero_card) # (We pass 'self' for the brain)
signal focus_changed(new_pips)

# --- UNIQUE Data ---
var hero_data: HeroData
var current_focus_pips: int = 0
var current_role_index: int = 0

# --- UNIQUE UI Node References ---
@onready var focus_bar: HBoxContainer = $Panel/FocusBar
@onready var name_label: Label = $Panel/Title
@onready var anim = $AnimationPlayer

# ===================================================================
# 1. SETUP & READY
# ===================================================================

func setup(data: HeroData):
	self.hero_data = data
	setup_base(data.base_stats)
	name_label.text = hero_data.base_stats.actor_name

	if hero_data.portrait:
		portrait_rect.texture = hero_data.portrait

	self.current_focus_pips = 0
	add_to_group("player")
	update_focus_bar()


func on_turn_started() -> void:
	anim.play("move_up")
	if current_focus_pips < 10:
		current_focus_pips += 1
		update_focus_bar()
		print(hero_data.base_stats.actor_name, " gained 1 Focus (now at ", current_focus_pips, ")")
	await super.on_turn_started()
	return


func on_turn_ended() -> void:
	anim.play("move_down")


func get_current_role() -> Role:
	if hero_data.unlocked_roles.size() > 0:
		return hero_data.unlocked_roles[current_role_index]
	return null

func get_previous_role() -> Role:
	var role_count = hero_data.unlocked_roles.size()
	if role_count == 0: return null
	var prev_index = (current_role_index - 1 + role_count) % role_count
	return hero_data.unlocked_roles[prev_index]

func get_next_role() -> Role:
	var role_count = hero_data.unlocked_roles.size()
	if role_count == 0: return null
	var next_index = (current_role_index + 1) % role_count
	return hero_data.unlocked_roles[next_index]

func shift_role(direction: String):
	var role_count = hero_data.unlocked_roles.size()
	if role_count == 0: return

	if direction == "left":
		current_role_index = (current_role_index - 1 + role_count) % role_count
	else:
		current_role_index = (current_role_index + 1) % role_count

	role_shifted.emit(self) # Pass 'self'

func update_focus_bar():
	var pips = focus_bar.get_children()
	for i in pips.size():
		if i < current_focus_pips:
			pips[i].visible = true
		else:
			pips[i].visible = false
	focus_changed.emit(current_focus_pips)


func _on_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.
