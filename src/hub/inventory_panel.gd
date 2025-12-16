extends Control
class_name InventoryPanel

signal hero_stats_updated

# --- EXPORTS ---
@export var item_button_scene: PackedScene

# --- UI REFS ---
# Adjust these paths to match your actual scene tree
@onready var header_label: Label = $Header/Label
@onready var grid: VBoxContainer = $InventoryGrid

# --- STATE ---
enum Mode { VIEW, EQUIP, TUNE, MOD }
var current_mode: Mode = Mode.VIEW
var active_hero: HeroData
var active_equipment: Equipment
var active_slot: Equipment.Slot

# --- SETUP ---
func setup(hero: HeroData):
	active_hero = hero
	# Default to View mode (or just clear)
	current_mode = Mode.VIEW
	_refresh_view_mode()

func request_equip_mode(item: Equipment, slot_type: Equipment.Slot) -> bool:
	if current_mode == Mode.EQUIP and active_equipment == item and active_slot == slot_type:
		# TOGGLE OFF
		_close_panel()
		return false

	# NEW MODE
	on_equip_requested(item, slot_type)
	return true

func request_tune_mode(item: Equipment) -> bool:
	if current_mode == Mode.TUNE and active_equipment == item:
		# TOGGLE OFF
		_close_panel()
		return false

	on_tune_requested(item)
	return true

func _close_panel():
	current_mode = Mode.VIEW
	active_equipment = null
	header_label.text = "Inventory"
	_clear_grid()

func on_equip_requested(item: Equipment, slot_type: Equipment.Slot):
	current_mode = Mode.EQUIP

	active_equipment = item
	active_slot = slot_type

	var slot_name = "Weapon" if slot_type == Equipment.Slot.WEAPON else "Armor"
	header_label.text = "Equip " + slot_name

	_populate_grid_with_equipment(slot_type)

func on_tune_requested(item: Equipment):
	if not item: return
	current_mode = Mode.TUNE
	active_equipment = item
	header_label.text = "Tune: " + item.item_name
	_populate_grid_with_materials(item)

func on_mod_requested(item: Equipment, slot_idx: int):
	if not item: return
	current_mode = Mode.MOD
	active_equipment = item
	header_label.text = "Select Mod"
	_populate_grid_with_mods(item)

func _refresh_view_mode():
	# Default state: Show all uneven/unequipped items? Or just empty?
	header_label.text = "Inventory"
	_clear_grid()
	# _populate_grid_all()

func _populate_grid_with_equipment(slot_type: Equipment.Slot):
	_clear_grid()

	# 1. Get all unequipped items of the correct slot
	# We look at the permanent storage
	var available_gear = []
	for item in SaveSystem.inventory_equipment:
		if item.slot == slot_type:
			available_gear.append(item)

	# 2. Spawn Buttons
	for item in available_gear:
		var btn = _spawn_grid_button(item, item.slot, 1)
		btn.pressed.connect(_on_equipment_clicked.bind(item))

	if available_gear.is_empty():
		_spawn_empty_message("No matching equipment found.")

func _populate_grid_with_materials(target_item: Equipment):
	_clear_grid()

	for id in SaveSystem.inventory.keys():
		var resource = ItemDatabase.get_item_resource(id)

		# Check if it is a MATERIAL
		if resource is InventoryItem and resource.category == InventoryItem.ItemCategory.MATERIAL:

			# --- 1. REMOVED TYPE FILTER ---
			# We no longer check 'is_compatible_with'.
			# We show ALL materials.

			var count = SaveSystem.inventory[id]
			var btn = _spawn_grid_button(resource, target_item.slot, count)

			btn.pressed.connect(_on_material_clicked.bind(resource, btn))

func _populate_grid_with_mods(target_item: Equipment):
	_clear_grid()

	for id in SaveSystem.inventory.keys():
		var resource = ItemDatabase.get_item_resource(id)

		if resource is EquipmentMod:
			if target_item.tier >= resource.min_tier_required:
				var count = SaveSystem.inventory[id]
				var btn = _spawn_grid_button(resource, -1, count)
				btn.pressed.connect(_on_mod_clicked.bind(resource, btn))

func _on_equipment_clicked(new_item: Equipment):
	# 1. Swap Logic
	# Remove new_item from inventory
	SaveSystem.inventory_equipment.erase(new_item)

	# If we had an old item, put it back in inventory
	var old_item = null
	if active_slot == Equipment.Slot.WEAPON:
		old_item = active_hero.weapon
		active_hero.weapon = new_item
	elif active_slot == Equipment.Slot.ARMOR:
		old_item = active_hero.armor
		active_hero.armor = new_item

	if old_item:
		SaveSystem.inventory_equipment.append(old_item)

	AudioManager.play_sfx("terminal")
	_populate_grid_with_equipment(active_slot)
	hero_stats_updated.emit()

func _on_material_clicked(mat: InventoryItem, btn_ui: ItemButton):
	if not active_equipment: return

	if not active_equipment.can_add_xp():
		print("Max Rank reached for this Tier.")
		return

	if SaveSystem.remove_inventory_item(mat.id, 1): # Assumes ID is on the resource logic or we find it
		# Note: UpgradeMaterial resource might not store its own ID string depending on your impl.
		# If it doesn't, we need to pass the ID string in _populate.
		# Assuming ItemDatabase returns a resource that has 'id' populated or we used the dict key.

		# 3. Apply XP
		var xp = mat.get_xp_value(active_equipment.slot)
		active_equipment.add_xp(xp)

		# 4. Visuals
		AudioManager.play_sfx("terminal") # Tick sound

		# Update button count
		# We need to look up the count again
		# We assume we can get the ID from somewhere.
		# If UpgradeMaterial doesn't have 'id', we need to pass it in bind.
		# Let's assume we pass ID in the bind for safety in future refactors.

		var new_count = SaveSystem.get_item_count(mat.id) # Assuming resource has .id
		btn_ui.update_quantity(new_count)

		if new_count <= 0:
			btn_ui.disabled = true

		hero_stats_updated.emit()

func _on_mod_clicked(mod: EquipmentMod, btn_ui: Control):
	# Logic to insert mod into active_equipment
	# ...
	pass

func _clear_grid():
	if not grid: return
	for child in grid.get_children():
		child.queue_free()

func _spawn_grid_button(resource: Resource, slot: int, count: int) -> Control:
	var btn = item_button_scene.instantiate() as ItemButton

	grid.add_child(btn)
	btn.setup(resource, slot, count)

	return btn

func _spawn_empty_message(msg: String):
	var l = Label.new()
	l.text = msg
	grid.add_child(l)
