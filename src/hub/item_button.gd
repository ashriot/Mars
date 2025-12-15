extends Button
class_name ItemButton

@onready var category_icon: TextureRect = $Header/Icon
@onready var label: Label = $Label
@onready var info: Label = $Label/Info


func setup(resource: Resource, amount: int):
	if resource is Equipment:
		_setup_equipment(resource)
	elif resource is InventoryItem:
		_setup_item(resource)

func _setup_equipment(item: Equipment):
	category_icon.texture = ItemDatabase.get_equipment_icon(item)
	label.text = item.get_display_name()
	info.text = "Rk." + str(item.rank) + "/" + str(item.get_rank_cap())

func _setup_item(item: InventoryItem):
	category_icon.texture = ItemDatabase.get_material_icon(item)
	label.text = item.name
	info.text = "+" + str(item.get_xp_value()) +"EP"
