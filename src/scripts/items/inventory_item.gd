extends Resource
class_name InventoryItem

enum ItemCategory { MATERIAL, COMPONENT }
enum ItemType { WEAPON, ARMOR }
enum Rarity { COMMON, RARE }

@export_group("Identity")
@export var name: String = "Iron Filament"
@export var icon: Texture
@export_multiline var description: String = ""

@export_group("Properties")
@export var category: ItemCategory = ItemCategory.MATERIAL
@export var type: ItemType = ItemType.WEAPON
@export_range(1, 5) var tier: int = 1
@export var rarity: Rarity = Rarity.COMMON

var id: String:
	get: return _generate_id()

func _generate_id() -> String:
	var prefix = ""
	var type_str = ""
	var suffix = ""

	# 1. Determine Prefix (Category)
	if category == ItemCategory.MATERIAL:
		prefix = "mat"
	elif category == ItemCategory.COMPONENT:
		prefix = "comp"

	# 2. Determine Type String
	if type == ItemType.WEAPON:
		type_str = "weap"
	elif type == ItemType.ARMOR:
		type_str = "arm"

	# 3. Determine Suffix (Rarity only for Components)
	if category == ItemCategory.COMPONENT:
		var rarity_str = "common" if rarity == Rarity.COMMON else "rare"
		suffix = "_%s_%d_%s" % [type_str, tier, rarity_str]
	else:
		# Materials don't use rarity in the ID structure we defined earlier
		suffix = "_%s_%d" % [type_str, tier]

	return prefix + suffix
