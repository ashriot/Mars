extends Button
class_name SkillTreeNode

signal node_clicked(node_ui)

enum NodeState { LOCKED, AVAILABLE, UNLOCKED }

# State
var role_node_data: RoleNode
var state: int = 0
var depth: int = 0
var hero_data: HeroData
var role_def: RoleDefinition # <-- STORE THIS

# UI References
@onready var icon_rect: TextureRect = $Panel/Icon
@onready var owned_highlight: Panel = $Owned
@onready var label: Label = $Label
@onready var cost_label: Label = $XpCost

# Arrow References
@onready var arrow_left: TextureRect = $Arrows/Left
@onready var arrow_down: TextureRect = $Arrows/Down
@onready var arrow_right: TextureRect = $Arrows/Right


func setup(node: RoleNode, hero: HeroData, def: RoleDefinition, current_depth: int):
	role_node_data = node
	hero_data = hero
	role_def = def # Store the definition for this specific tree
	depth = current_depth

	var is_owned = node.generated_id in hero.unlocked_node_ids

	# 1. Setup Button Visuals
	_update_button_visuals(is_owned)

	# 2. Setup Arrow Visuals
	_update_arrows(is_owned)

func set_availability(is_available: bool, can_afford: bool):
	if state == NodeState.UNLOCKED: return

	if is_available:
		state = NodeState.AVAILABLE
		disabled = not can_afford
		if can_afford:
			self.modulate = Color.WHITE
			cost_label.modulate = Color.WHITE
		else:
			self.modulate = Color.DARK_GRAY
			cost_label.modulate = Color.DARK_GRAY
			modulate.a = 0.5
	else:
		state = NodeState.LOCKED
		disabled = true
		modulate.a = 0.25

func _update_button_visuals(is_owned: bool):
	cost_label.visible = not is_owned
	owned_highlight.visible = is_owned
	icon_rect.texture = null

	match role_node_data.type:
		RoleNode.RewardType.STAT:
			label.text = ActorStats.Stats.keys()[role_node_data.stat_type] + " +%d" % role_node_data.stat_value

		RoleNode.RewardType.ACTION:
			var slot = role_node_data.action_slot_index

			# Check if the Definition has an action in this slot
			if slot >= 0 and slot < role_def.actions.size():
				var resource = role_def.actions[slot]
				if resource:
					label.text = resource.action_name
					icon_rect.texture = resource.icon
			else:
				label.text = "Unknown Action"

		RoleNode.RewardType.SHIFT_ACTION:
			var resource = role_def.shift_action
			label.text = resource.action_name
			icon_rect.texture = resource.icon

		RoleNode.RewardType.PASSIVE:
			var resource = role_def.passive
			label.text = resource.action_name
			icon_rect.texture = resource.icon

	cost_label.text = str(role_node_data.calculated_xp_cost) + " XP" # Simplified formatting for now

	if is_owned:
		state = NodeState.UNLOCKED
		disabled = true
		self.modulate.a = 1.0
		cost_label.hide()

func _update_arrows(is_self_owned: bool):
	arrow_down.visible = false
	arrow_left.visible = false
	arrow_right.visible = false

	# Helper to check a specific slot
	var _check_slot = func(target_node: RoleNode, arrow: Control):
		if target_node:
			arrow.visible = true
			if is_self_owned:
				var is_child_owned = target_node.generated_id in hero_data.unlocked_node_ids
				arrow.modulate = Color.WHITE if is_child_owned else Color.GRAY
			else:
				arrow.modulate = Color(1, 1, 1, 0.5)

	# Call for each slot
	_check_slot.call(role_node_data.child_node, arrow_down)
	_check_slot.call(role_node_data.left_node, arrow_left)
	_check_slot.call(role_node_data.right_node, arrow_right)

func _pressed():
	node_clicked.emit(self)
