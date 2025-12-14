extends Control
class_name InventoryPanel

@export var equipment_slot_scene: PackedScene # For Weapon/Armor slots
@export var inventory_item_scene: PackedScene # For the grid

@onready var equipment_container: VBoxContainer = $EquipmentSlots
@onready var inventory_grid: GridContainer = $InventoryGrid

var current_hero: HeroData

func setup(hero: HeroData):
	current_hero = hero
	_refresh_equipment()
	_refresh_inventory()

func _refresh_equipment():
	# Display Weapon and Armor slots
	pass

func _refresh_inventory():
	# Load items from SaveSystem.inventory and SaveSystem.inventory_equipment
	pass
