extends Control
class_name InventoryPanel

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
	#header_label.text = "Inventory"
	_clear_grid()
	# Optional: List everything in a read-only mode
	# _populate_grid_all()

func _populate_grid_with_equipment(slot_type: Equipment.Slot):
	_clear_grid()

	# 1. Get all unequipped items of the correct slot
	# We look at the permanent storage
	var available_gear = []
	for item in SaveSystem.inventory_equipment:
		if item.slot == slot_type:
			# Optional: Check if equipped by someone else?
			# For Physical Ownership, usually items in 'inventory_equipment' are NOT equipped.
			available_gear.append(item)

	# 2. Spawn Buttons
	for item in available_gear:
		var btn = _spawn_grid_button(item, 1)
		btn.pressed.connect(_on_equipment_clicked.bind(item))

	if available_gear.is_empty():
		_spawn_empty_message("No matching equipment found.")

func _populate_grid_with_materials(target_item: Equipment):
	_clear_grid()

	for id in SaveSystem.inventory.keys():
		var resource = ItemDatabase.get_item_resource(id)

		# Check if it is a MATERIAL and compatible
		if resource is InventoryItem and resource.category == InventoryItem.ItemCategory.MATERIAL:

			# Simple compatibility check
			if resource.is_compatible_with(target_item):
				var count = SaveSystem.inventory[id]
				var btn = _spawn_grid_button(resource, count)
				btn.pressed.connect(_on_material_clicked.bind(resource, btn))

func _populate_grid_with_mods(target_item: Equipment):
	_clear_grid()

	for id in SaveSystem.inventory.keys():
		var resource = ItemDatabase.get_item_resource(id)

		if resource is EquipmentMod:
			if target_item.tier >= resource.min_tier_required:
				var count = SaveSystem.inventory[id]
				var btn = _spawn_grid_button(resource, count)
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

	AudioManager.play_sfx("terminal") # Equip sound

	# 2. Refresh UI
	# We need to tell the PartyMenu to refresh the HeroPanel
	# Or emit a signal up
	# For now, just refresh this grid (it should remove the clicked item and add the old one)
	_populate_grid_with_equipment(active_slot)

	# Force hero panel update (Quick and dirty way, better to use signals)
	# But since HeroPanel reads from HeroData in _process or update functions,
	# we might need to explicitly trigger it.
	get_tree().call_group("hero_panel_ui", "setup", active_hero)

func _on_material_clicked(mat: InventoryItem, btn_ui: Control):
	if not active_equipment: return

	# 1. Check Cap
	if not active_equipment.can_add_xp():
		print("Max Rank reached for this Tier.")
		return

	# 2. Consume
	if SaveSystem.remove_inventory_item(mat.id, 1): # Assumes ID is on the resource logic or we find it
		# Note: UpgradeMaterial resource might not store its own ID string depending on your impl.
		# If it doesn't, we need to pass the ID string in _populate.
		# Assuming ItemDatabase returns a resource that has 'id' populated or we used the dict key.

		# 3. Apply XP
		var xp = mat.get_xp_value() # Your calculation function
		active_equipment.add_xp(xp)

		# 4. Visuals
		AudioManager.play_sfx("terminal") # Tick sound

		# Update button count
		# We need to look up the count again
		# We assume we can get the ID from somewhere.
		# If UpgradeMaterial doesn't have 'id', we need to pass it in bind.
		# Let's assume we pass ID in the bind for safety in future refactors.

		var new_count = SaveSystem.get_item_count(mat.id) # Assuming resource has .id
		if btn_ui.has_method("set_count"):
			btn_ui.set_count(new_count)

		if new_count <= 0:
			btn_ui.disabled = true

		# Force Hero Panel Update to show XP bar growing
		get_tree().call_group("hero_panel_ui", "setup", active_hero)

func _on_mod_clicked(mod: EquipmentMod, btn_ui: Control):
	# Logic to insert mod into active_equipment
	# ...
	pass

func _clear_grid():
	if not grid: return
	for child in grid.get_children():
		child.queue_free()

func _spawn_grid_button(resource: Resource, count: int) -> Control:
	var btn
	if item_button_scene:
		btn = item_button_scene.instantiate() as ItemButton
	else:
		# Fallback if no scene assigned
		btn = Button.new()
		btn.text = "Item"
		btn.custom_minimum_size = Vector2(100, 50)

	grid.add_child(btn)

	# Setup Data
	btn.setup(resource, count)

	return btn

func _spawn_empty_message(msg: String):
	var l = Label.new()
	l.text = msg
	grid.add_child(l)
