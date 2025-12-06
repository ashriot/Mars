extends Button
class_name SkillTreeNode

signal node_clicked(node_ui)

# State
var role_node_data: RoleNode
var state: int = 0 # 0=Locked, 1=Available, 2=Unlocked
var depth: int = 0

# UI References
@onready var icon_rect: TextureRect = $Panel/Icon
@onready var label: Label = $Label
@onready var cost_label: Label = $XpCost

# --- NEW: ARROW REFERENCES ---
@onready var arrow_left: TextureRect = $Arrows/Left
@onready var arrow_down: TextureRect = $Arrows/Down
@onready var arrow_right: TextureRect = $Arrows/Right

func setup(node: RoleNode, hero: HeroData, current_depth: int):
	role_node_data = node
	depth = current_depth

	var is_owned = node.generated_id in hero.unlocked_node_ids

	# 1. Setup Button Visuals
	_update_button_visuals(hero, is_owned)

	# 2. Setup Arrow Visuals
	_update_arrows(hero, is_owned)

func set_availability(is_available: bool, can_afford: bool):
	if state == 2: return # Already owned

	if is_available:
		state = 1
		disabled = false
		if can_afford:
			self.modulate = Color.WHITE
			cost_label.modulate = Color.GREEN
		else:
			self.modulate = Color.LIGHT_GRAY
			cost_label.modulate = Color.RED
	else:
		state = 0
		disabled = true
		self.modulate = Color(0.3, 0.3, 0.3, 0.5)

func _update_button_visuals(hero: HeroData, is_owned: bool):
	cost_label.visible = not is_owned
	match role_node_data.type:
		RoleNode.RewardType.STAT:
			label.text = ActorStats.Stats.keys()[role_node_data.stat_type] + " +%d" % role_node_data.stat_value

		RoleNode.RewardType.ACTION:
			var resource: Action = hero.current_role.actions[role_node_data.action_slot_index]
			if resource:
				label.text = resource.action_name
				icon_rect.texture = resource.icon

		RoleNode.RewardType.PASSIVE:
			label.text = role_node_data.unlock_resource.condition_name

	cost_label.text = str(role_node_data.calculated_xp_cost) + " XP"

	if is_owned:
		state = 2
		disabled = true
		self.modulate = Color.GOLD
		cost_label.hide()

func _update_arrows(hero: HeroData, is_self_owned: bool):
	arrow_down.visible = false
	arrow_left.visible = false
	arrow_right.visible = false

	# Helper to check a specific slot
	var _check_slot = func(target_node: RoleNode, arrow: Control):
		if target_node:
			arrow.visible = true
			if is_self_owned:
				var is_child_owned = target_node.generated_id in hero.unlocked_node_ids
				arrow.modulate = Color.GOLD if is_child_owned else Color.WHITE
			else:
				arrow.modulate = Color(1, 1, 1, 0.5) # Dim

	# Call for each slot
	_check_slot.call(role_node_data.child_node, arrow_down)
	_check_slot.call(role_node_data.left_node, arrow_left)
	_check_slot.call(role_node_data.right_node, arrow_right)

func _pressed():
	node_clicked.emit(self)
