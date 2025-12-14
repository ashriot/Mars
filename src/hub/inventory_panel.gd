extends Control
class_name InventoryPanel

@export var equipment_slot_scene: PackedScene # For Weapon/Armor slots
@export var inventory_item_scene: PackedScene # For the grid

@onready var inventory_grid: GridContainer = $InventoryGrid

var current_hero: HeroData

func setup(hero: HeroData):
	current_hero = hero
	_refresh_inventory()

func _refresh_inventory():
	# Load items from SaveSystem.inventory and SaveSystem.inventory_equipment
	pass
