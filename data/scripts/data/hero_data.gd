extends Resource
class_name HeroData

@export var hero_id: String = "asher"
@export var hero_name: String = "Asher"
@export var portrait: Texture

# --- Equipment ---
@export var weapon: Equipment
@export var armor: Equipment
@export var accessory_1: Equipment
@export var accessory_2: Equipment

# --- Progression Data ---
@export var role_definitions: Array[RoleDefinition] = []

@export var unlocked_role_ids: Array[String] = []
@export var unlocked_node_ids: Array[String] = []

@export var active_role_index: int = 0
@export var injuries: int = 0
@export var current_xp: int = 0

# --- Runtime Data (Not Saved) ---
var stats: ActorStats
var battle_roles: Dictionary = {} # Key: role_id, Value: RoleData

# ===================================================================
# 1. STAT CALCULATION
# ===================================================================
func calculate_stats():
	stats = ActorStats.new()
	stats.actor_name = hero_name

	if weapon:
		var weapon_stats = weapon.calculate_stats()
		_add_stats(stats, weapon_stats)
		_apply_special_effect(stats, weapon)
	if armor:
		var armor_stats = armor.calculate_stats()
		_add_stats(stats, armor_stats)
		_apply_special_effect(stats, armor)
	if accessory_1:
		var acc1_stats = accessory_1.calculate_stats()
		_add_stats(stats, acc1_stats)
		_apply_special_effect(stats, accessory_1)
	if accessory_2:
		var acc2_stats = accessory_2.calculate_stats()
		_add_stats(stats, acc2_stats)
		_apply_special_effect(stats, accessory_2)

	# Apply Tree Stats
	for role_def in role_definitions:
		if role_def.root_node:
			role_def.init_structure() # Ensure IDs exist
			_process_node_stats(role_def.root_node, stats)

	print("\n=== STATS FOR: ", stats.actor_name, " ===")
	for prop in stats.get_property_list():
		# This filter ensures we only print variables defined in the script
		# (skips internal Godot stuff like 'reference', 'resource_path', etc.)
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			print(prop.name, ": ", stats.get(prop.name))
	print("========================\n")

func _add_stats(base: ActorStats, additional: ActorStats):
	base.max_hp += additional.max_hp
	base.starting_guard += additional.starting_guard
	base.attack += additional.attack
	base.psyche += additional.psyche
	base.overload += additional.overload
	base.speed += additional.speed
	base.aim = clampi(base.aim + additional.aim, 0, 75)
	base.kinetic_defense = clampi(base.kinetic_defense + additional.kinetic_defense, 0, 90)
	base.energy_defense = clampi(base.energy_defense + additional.energy_defense, 0, 90)

func _apply_special_effect(actor_stats: ActorStats, equipment: Equipment):
	match equipment.special_effect:
		"glass_cannon":
			var penalty = int(actor_stats.max_hp * abs(equipment.special_effect_value) / 100.0)
			actor_stats.max_hp = max(1, actor_stats.max_hp - penalty)
		_: pass

func _process_node_stats(node: RoleNode, accum_stats: ActorStats):
	# Check flat list
	if not node.generated_id in unlocked_node_ids:
		return

	if node.type == RoleNode.RewardType.STAT:
		accum_stats.add_stat(node.stat_type, node.stat_value)

	for child in node.next_nodes:
		_process_node_stats(child, accum_stats)

# ===================================================================
# 2. BATTLE ROLE GENERATION
# ===================================================================

func rebuild_battle_roles():
	battle_roles.clear()

	for def in role_definitions:
		if def.role_id in unlocked_role_ids:
			var role_data = RoleData.new()
			role_data.role_id = def.role_id
			role_data.role_name = def.role_name
			role_data.icon = def.icon
			role_data.color = def.color
			battle_roles[def.role_id] = role_data
			def.init_structure()
			if def.root_node:
				_bake_tree_into_role(def.root_node, role_data)

func get_battle_role(role_id: String) -> RoleData:
	return battle_roles.get(role_id)

func _bake_tree_into_role(node: RoleNode, target_role: RoleData):
	# Check flat list
	if not node.generated_id in unlocked_node_ids:
		return

	match node.type:
		RoleNode.RewardType.ACTION:
			if node.unlock_resource is Action:
				if node.action_slot_index < 0:
					push_error("Action slot cannot be less than 0!")
				var action = node.unlock_resource
				if target_role.actions.size() < 4:
					target_role.actions.resize(4)
				target_role.actions[node.action_slot_index] = action

		RoleNode.RewardType.PASSIVE:
			if node.unlock_resource is Action:
				target_role.passive = node.unlock_resource

		RoleNode.RewardType.SHIFT_ACTION:
			if node.unlock_resource is Action:
				target_role.passive = node.unlock_resource

	for child in node.next_nodes:
		_bake_tree_into_role(child, target_role)

# ===================================================================
# 3. SAVE / LOAD SYSTEM
# ===================================================================

func unlock_new_role(role_id: String):
	if not role_id in unlocked_role_ids:
		unlocked_role_ids.append(role_id)

func unlock_node(node: RoleNode):
	if not node.generated_id in unlocked_node_ids:
		unlocked_node_ids.append(node.generated_id)

func get_save_data() -> Dictionary:
	return {
		"hero_id": hero_id,
		"injuries": injuries,
		"current_xp": current_xp,
		"active_role": active_role_index,
		"weapon": weapon.get_save_data() if weapon else {},
		"armor": armor.get_save_data() if armor else {},
		"acc1": accessory_1.get_save_data() if accessory_1 else {},
		"acc2": accessory_2.get_save_data() if accessory_2 else {},
		"unlocked_role_ids": unlocked_role_ids,
		"unlocked_node_ids": unlocked_node_ids,
	}

func load_from_save_data(data: Dictionary):
	injuries = data.get("injuries", 0)
	current_xp = data.get("current_xp", 0)
	active_role_index = data.get("active_role", 0)

	var loaded_node_ids = data.get("unlocked_node_ids", [])
	unlocked_node_ids.clear()
	for id in loaded_node_ids:
		unlocked_node_ids.append(str(id))

	# Load Role IDs
	var loaded_role_ids = data.get("unlocked_role_ids", [])
	unlocked_role_ids.clear()
	for id in loaded_role_ids:
		unlocked_role_ids.append(str(id))

	if data.get("weapon"): weapon = Equipment.create_from_save_data(data.weapon)
	if data.get("armor"): armor = Equipment.create_from_save_data(data.armor)
	if data.get("acc1"): accessory_1 = Equipment.create_from_save_data(data.acc1)
	if data.get("acc2"): accessory_2 = Equipment.create_from_save_data(data.acc2)

# --- XP LOGIC ---
func gain_xp(amount: int):
	current_xp += amount

func can_afford_node(node: RoleNode) -> bool:
	return current_xp >= node.calculated_xp_cost

func spend_xp(amount: int):
	if current_xp >= amount:
		current_xp -= amount
	else:
		push_error("HeroData: Tried to spend more XP than available!")
