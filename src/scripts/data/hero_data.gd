extends Resource
class_name HeroData

@export var hero_id: String = "asher"
@export var hero_name: String = "Asher"
@export var portrait: Texture

# --- Equipment ---
@export var weapon: Equipment
@export var armor: Equipment

# --- Progression Data ---
@export var role_definitions: Array[RoleDefinition] = []

@export var unlocked_role_ids: Array[String] = []
@export var unlocked_node_ids: Array[String] = []
var role_progress: Dictionary[String, HeroRoleProgress] = {}

@export var active_role_index: int = 0
@export var injuries: int = 0
@export var current_xp: int = 0

@export var boon_focused: bool = false
@export var boon_armored: bool = false

# --- Runtime Data (Not Saved) ---
var stats: ActorStats
var battle_roles: Dictionary = {}
var unlocked_roles:
	get: return role_definitions.filter(func(role):
		return role.role_id in unlocked_role_ids)
var current_role: RoleDefinition :
	get : return (role_definitions[active_role_index])


func calculate_stats():
	stats = _build_equipment_stats()

	# Apply legacy authored tree stats until progression migration is complete.
	for role_def in role_definitions:
		if role_def.root_node:
			role_def.init_structure() # Ensure IDs exist
			_process_node_stats(role_def.root_node, stats)
	stats.aim += 10

func build_equipment_base_stats() -> ActorStats:
	var built_stats := _build_equipment_stats()
	built_stats.aim += 10
	return built_stats

func _build_equipment_stats() -> ActorStats:
	var built_stats := ActorStats.new()
	built_stats.actor_name = hero_name

	if weapon:
		var weapon_stats = weapon.calculate_stats()
		_add_stats(built_stats, weapon_stats)
	if armor:
		var armor_stats = armor.calculate_stats()
		_add_stats(built_stats, armor_stats)

	return built_stats

	#print(stats)

func _add_stats(base: ActorStats, additional: ActorStats):
	base.max_hp += additional.max_hp
	base.starting_guard += additional.starting_guard
	base.starting_focus += additional.starting_focus
	base.attack += additional.attack
	base.psyche += additional.psyche
	base.overload += additional.overload
	base.speed += additional.speed
	base.aim = clampi(base.aim + additional.aim, 0, 75)
	base.precision += additional.precision
	base.kinetic_defense = clampi(base.kinetic_defense + additional.kinetic_defense, 0, 90)
	base.energy_defense = clampi(base.energy_defense + additional.energy_defense, 0, 90)

func _process_node_stats(node: RoleNode, accum_stats: ActorStats):
	if not node.generated_id in unlocked_node_ids: return

	if node.type == RoleNode.RewardType.STAT:
		accum_stats.add_stat(node.stat_type, node.stat_value)

	# Explicit Checks
	if node.child_node: _process_node_stats(node.child_node, accum_stats)
	if node.left_node:  _process_node_stats(node.left_node, accum_stats)
	if node.right_node: _process_node_stats(node.right_node, accum_stats)

func _bake_tree_into_role(node: RoleNode, def: RoleDefinition, unlocked_ids: Array, target_role: RoleData):

	# 1. Stop if this node is locked
	if not node.generated_id in unlocked_ids:
		return

	# 2. Apply Reward based on DEFINITION Data
	match node.type:
		RoleNode.RewardType.ACTION:
			var slot = node.action_slot_index

			# Safety check: Does the definition actually have an action for this slot?
			if slot >= 0 and slot < def.actions.size():
				var action_res = def.actions[slot]

				# Ensure target array is big enough (4 slots)
				if target_role.actions.size() < 4:
					target_role.actions.resize(4)

				# Place the action in the correct slot
				target_role.actions[slot] = action_res

		RoleNode.RewardType.PASSIVE:
			# The definition holds the passive, the node just unlocks it
			if def.passive:
				target_role.passive = def.passive

		RoleNode.RewardType.SHIFT_ACTION:
			if def.shift_action:
				target_role.shift_action = def.shift_action

	# 3. Recurse
	if node.child_node: _bake_tree_into_role(node.child_node, def, unlocked_ids, target_role)
	if node.left_node:  _bake_tree_into_role(node.left_node, def, unlocked_ids, target_role)
	if node.right_node: _bake_tree_into_role(node.right_node, def, unlocked_ids, target_role)

func rebuild_battle_roles():
	battle_roles.clear()

	for def in role_definitions:
		if def.role_id in unlocked_role_ids:
			var role_data = RoleData.new()
			role_data.source_definition = def
			battle_roles[def.role_id] = role_data
			def.init_structure()
			if def.root_node:
				_bake_tree_into_role(def.root_node, def, unlocked_node_ids, role_data)

func get_battle_role(role_id: String) -> RoleData:
	return battle_roles.get(role_id)

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
		"boon_focused": boon_focused,
		"boon_armored": boon_armored,
		"current_xp": current_xp,
		"active_role": active_role_index,
		"weapon": weapon.get_save_data() if weapon else {},
		"armor": armor.get_save_data() if armor else {},
		"unlocked_role_ids": unlocked_role_ids,
		"unlocked_node_ids": unlocked_node_ids,
		"role_progress": _role_progress_save_data(),
	}

func _role_progress_save_data() -> Dictionary:
	var saved := {}
	for role_id in role_progress:
		saved[role_id] = role_progress[role_id].to_save_data()
	return saved

func load_from_save_data(data: Dictionary, expected_revisions: Dictionary = {}) -> Array[String]:
	var progression_issues: Array[String] = []
	injuries = data.get("injuries", 0)
	boon_focused = data.get("boon_focused", false)
	boon_armored = data.get("boon_armored", false)
	current_xp = data.get("current_xp", 0)
	active_role_index = data.get("active_role", 0)

	var loaded_node_ids = data.get("unlocked_node_ids", [])
	unlocked_node_ids.clear()
	for id in loaded_node_ids:
		unlocked_node_ids.append(str(id))

	role_progress.clear()
	var loaded_progress: Variant = data.get("role_progress", {})
	if loaded_progress is Dictionary:
		for role_id in loaded_progress:
			if not role_id is String or role_id.is_empty():
				progression_issues.append(str(role_id))
				continue
			var record := HeroRoleProgress.from_save_data(loaded_progress[role_id])
			if record == null:
				progression_issues.append(role_id)
				continue
			role_progress[role_id] = record
			if expected_revisions.has(role_id) and expected_revisions[role_id] is int and record.content_revision != expected_revisions[role_id]:
				progression_issues.append(role_id)
	elif data.has("role_progress"):
		progression_issues.append("role_progress")

	# Load Role IDs
	var loaded_role_ids = data.get("unlocked_role_ids", [])
	unlocked_role_ids.clear()
	for id in loaded_role_ids:
		unlocked_role_ids.append(str(id))

	if data.get("weapon"): weapon = Equipment.create_from_save_data(data.weapon)
	if data.get("armor"): armor = Equipment.create_from_save_data(data.armor)
	return progression_issues

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
