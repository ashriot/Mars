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

# ===================================================================
# LOGIC
# ===================================================================

func _generate_id() -> String:
	var prefix = "mat" if category == ItemCategory.MATERIAL else "comp"
	var type_str = "weap" if type == ItemType.WEAPON else "arm"
	var suffix = "_%s_%d" % [type_str, tier]

	if category == ItemCategory.COMPONENT:
		var rarity_str = "common" if rarity == Rarity.COMMON else "rare"
		suffix += "_" + rarity_str

	return prefix + suffix

# --- MERGED LOGIC FROM UpgradeMaterial ---
func get_xp_value() -> int:
	# Only Materials give XP. Components are for Tier Upgrades.
	if category != ItemCategory.MATERIAL:
		return 0

	# Exponential Scaling: 10, 20, 40, 80, 160
	return 10 * int(pow(2, tier - 1))

# Optional: Helper to check compatibility
func is_compatible_with(equipment: Equipment) -> bool:
	if equipment.slot == Equipment.Slot.WEAPON:
		return type == ItemType.WEAPON
	elif equipment.slot == Equipment.Slot.ARMOR:
		return type == ItemType.ARMOR
	return false
