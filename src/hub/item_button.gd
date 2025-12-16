extends Control
class_name ItemButton

signal pressed

@onready var category_icon: TextureRect = $Button/Header/Icon
@onready var label: Label = $Button/Label
@onready var info: Label = $Button/Label/Info
@onready var qty: Label = $Qty

var _target_slot_context: int = -1
var _item_ref: Resource

var disabled: bool:
	get: return $Button.disabled
	set(value): $Button.disabled = value


func setup(resource: Resource, slot_type: int, amount: int):
	_item_ref = resource
	_target_slot_context = slot_type
	if resource is Equipment:
		_setup_equipment(resource)
	elif resource is InventoryItem:
		_setup_item(resource)
	update_quantity(amount)

func update_quantity(amount: int):
	if amount > 1:
		qty.text = "x" + str(amount)
	else:
		qty.text = ""

func _setup_equipment(item: Equipment):
	category_icon.texture = ItemDatabase.get_equipment_icon(item)
	label.text = item.get_display_name()
	info.text = "Rk." + str(item.rank) + "/" + str(item.get_rank_cap())

func _setup_item(item: InventoryItem):
	category_icon.texture = ItemDatabase.get_material_icon(item)
	label.text = item.name

	if item.category == InventoryItem.ItemCategory.MATERIAL:
		var xp_val = item.get_xp_value(_target_slot_context)
		info.text = "+%d EP" % xp_val
		if _target_slot_context != -1 and item.type == _target_slot_context:
			info.modulate = Color.GREEN
		else:
			info.modulate = Color.WHITE
	else:
		info.text = ""

func _on_button_pressed() -> void:
	pressed.emit()
