extends Resource
class_name InventoryItem

enum ItemCategory { MATERIAL, COMPONENT }
enum ItemType { WEAPON, ARMOR }
enum Rarity { COMMON, RARE }

# --- IDENTITY ---
var id: String:
	get: return _generate_id()

@export_group("Visuals")
@export var name: String = "New Item"
@export var icon: Texture
@export_multiline var description: String = ""

@export_group("Properties")
@export var category: ItemCategory = ItemCategory.MATERIAL
@export var type: ItemType = ItemType.WEAPON
@export_range(1, 5) var tier: int = 1
@export var rarity: Rarity = Rarity.COMMON


func _generate_id() -> String:
	var prefix = "mat" if category == ItemCategory.MATERIAL else "comp"
	var type_str = "weap" if type == ItemType.WEAPON else "arm"
	var suffix = "_%s_%d" % [type_str, tier]

	if category == ItemCategory.COMPONENT:
		var rarity_str = "common" if rarity == Rarity.COMMON else "rare"
		suffix += "_" + rarity_str

	return prefix + suffix

func get_xp_value(target_slot: int = -1) -> int:
	if category != ItemCategory.MATERIAL:
		return 0

	var base_val = 20 * tier

	var matches = false
	if target_slot != -1 and target_slot == type:
		matches = true

	if matches:
		return int(base_val * 1.5)

	return base_val

func is_compatible_with(equipment: Equipment) -> bool:
	if equipment.slot == Equipment.Slot.WEAPON:
		return type == ItemType.WEAPON
	elif equipment.slot == Equipment.Slot.ARMOR:
		return type == ItemType.ARMOR
	return false
