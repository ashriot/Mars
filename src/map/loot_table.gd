extends Resource
class_name LootTable

enum LootType { BITS, MATERIAL, COMPONENT, EQUIPMENT }

# Weights for generic drops
@export var chance_bits: float = 0.4
@export var chance_material: float = 0.4
@export var chance_component: float = 0.15
@export var chance_equipment: float = 0.05

# (You would likely have arrays of Item IDs here to pick from)
# For this example, we'll simulate the result dictionary.

func roll_loot(tier: int, rarity_modifier: int = 0) -> Dictionary:
	var roll = randf()

	# 1. Determine Type
	var type = LootType.BITS
	if roll > (1.0 - chance_equipment): type = LootType.EQUIPMENT
	elif roll > (1.0 - chance_equipment - chance_component): type = LootType.COMPONENT
	elif roll > (1.0 - chance_equipment - chance_component - chance_material): type = LootType.MATERIAL

	# 2. Generate Content
	var result = { "type": type, "tier": tier }

	match type:
		LootType.BITS:
			# Base 50 * Tier, plus variance, plus rarity bonus
			var amount = (50 * tier) + (rarity_modifier * 50)
			amount = roundi(amount * randf_range(0.9, 1.1))
			result["amount"] = amount
			result["label"] = "Bits"

		LootType.MATERIAL:
			# Placeholder: Pick a random material ID based on Tier
			result["id"] = "mat_weapon_kinetic_t" + str(tier)
			result["amount"] = 1 + rarity_modifier
			result["label"] = "Weapon Parts"

		LootType.EQUIPMENT:
			# Placeholder: Pick ID
			result["id"] = "gun_rifle_mk1"
			result["label"] = "Rifle"

	return result
