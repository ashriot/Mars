# RunManager.gd
extends Node

signal run_bits_changed(new_amount: int)

enum RunResult { SUCCESS, RETREAT, DEFEAT }

var is_run_active: bool = false
var active_dungeon_map: DungeonMap = null
var dungeon_profile: DungeonProfile
var current_dungeon_tier: int = 0
var current_run_seed: int = 0
var run_bits: int = 0
var run_xp: int = 0
var run_inventory: Dictionary = {} # Key: ID, Value: Amount
var run_equipment_loot: Array[Equipment] = []

var party_roster: Array[HeroData]:
	get:
		return SaveSystem.party_roster

func add_run_xp(amount: int):
	run_xp += amount

func add_run_bits(amount: int):
	run_bits += amount
	run_bits_changed.emit(run_bits)

func add_loot_item(id: String, amount: int):
	if not run_inventory.has(id):
		run_inventory[id] = 0
	run_inventory[id] += amount
	print("Looted: %s x%d" % [id, amount])

func add_loot_equipment(id: String, tier: int, rank: int):
	# 1. Get base resource
	var item_res = ItemDatabase.get_item_resource(id)
	if not item_res: return

	# 2. Apply generated stats
	item_res.tier = tier
	item_res.rank = rank
	item_res.current_xp = 0 # Starts with 0 XP towards next rank

	# 3. Store in temporary run stash
	run_equipment_loot.append(item_res)
	print("Looted Equipment: %s (T%d R%d)" % [item_res.item_name, tier, rank])

func get_loot_scalar() -> float:
	var scalar = 1.0 + ((current_dungeon_tier - 1) * 0.25)

	# 2. (Future-Proofing) Add Party Level Logic here later
	# var avg_level = _get_average_party_level()
	# scalar += avg_level * 0.1

	return scalar

func get_run_save_data() -> Dictionary:
	if not active_dungeon_map: return {}
	var profile_path = dungeon_profile.resource_path
	var equip_data = []
	for item in run_equipment_loot:
		equip_data.append(item.get_save_data())

	return {
		"seed": current_run_seed,
		"run_bits": run_bits,
		"run_xp": run_xp,
		"run_inventory": run_inventory,
		"run_equipment": equip_data,
		"tier": current_dungeon_tier,
		"profile_path": profile_path,
		"map_data": active_dungeon_map.get_save_data()
	}

func restore_run():
	var run_data = SaveSystem.data.get("active_run")
	var path = run_data.get("profile_path", "")
	if path != "" and ResourceLoader.exists(path):
		dungeon_profile = load(path)

	if not run_data:
		push_error("Tried to restore run, but SaveSystem data has no 'active_run'!")
		return

	current_run_seed = int(run_data.seed)
	run_bits = int(run_data.get("run_bits", 0))
	run_xp = int(run_data.get("run_xp", 0))
	run_inventory = run_data.get("run_inventory", {})
	current_dungeon_tier = int(run_data.get("tier", 0))
	run_equipment_loot.clear()
	var saved_eq = run_data.get("run_equipment", [])
	for eq_dict in saved_eq:
		var item = Equipment.create_from_save_data(eq_dict)
		if item: run_equipment_loot.append(item)

	is_run_active = true
	if active_dungeon_map:
		seed(current_run_seed)
		await active_dungeon_map.load_from_save_data(run_data.map_data)

func spend_bits(amount: int) -> bool:
	if SaveSystem.bits >= amount:
		SaveSystem.bits -= amount
		return true
	return false

func get_bits() -> int:
	return SaveSystem.bits

func auto_save():
	# We only trigger the save if a run is happening.
	if is_run_active:
		SaveSystem.save_current_slot()

func commit_rewards(result: RunResult):
	var multiplier = 0.0

	match result:
		RunResult.SUCCESS: multiplier = 1.0
		RunResult.RETREAT: multiplier = 0.5
		RunResult.DEFEAT: multiplier = 0.0

	if result == RunResult.SUCCESS:
		for id in run_inventory:
			var amount = run_inventory[id]
			SaveSystem.add_inventory_item(id, amount)
		for item in run_equipment_loot:
			SaveSystem.add_equipment_to_inventory(item)
	elif result == RunResult.RETREAT:
		# Keep 50% of items? Or keep full items but lose bits?
		# Let's assume you keep 50% of the stack (rounded down)
		run_equipment_loot.clear()
		for id in run_inventory:
			var amount = floor(run_inventory[id] * 0.5)
			if amount > 0:
				SaveSystem.add_inventory_item(id, amount)

	# Wipe Backpack

	# Calculate Finals
	var final_bits = int(run_bits * multiplier)
	var final_xp = int(run_xp * multiplier)

	# Deposit
	if final_bits > 0:
		SaveSystem.bits += final_bits

	if final_xp > 0:
		SaveSystem.distribute_combat_xp(final_xp)

	# Reset Run State
	is_run_active = false
	run_bits = 0
	run_xp = 0
	run_inventory.clear()

	# Save immediately
	auto_save()
