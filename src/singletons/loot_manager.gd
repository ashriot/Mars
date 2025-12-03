# LootManager.gd (Autoload)
extends Node

enum LootType { BITS, MATERIAL, COMPONENT, EQUIPMENT }

# Generic weighting
const CHANCE_BITS = 0.4
const CHANCE_MAT = 0.35
const CHANCE_COMP = 0.15
const CHANCE_EQ = 0.1

# --- DEFINE RARITY COLORS ---
const COLOR_COMMON = Color.LIGHT_SLATE_GRAY
const COLOR_UNCOMMON = Color.YELLOW_GREEN
const COLOR_RARE = Color.CADET_BLUE
const COLOR_EPIC = Color.MEDIUM_PURPLE

# --- PUBLIC API ---
# DungeonMap calls this during generate_hex_grid()
func roll_loot(tier: int, rarity_mod: int) -> Dictionary:
	var roll = randf()
	var type = LootType.BITS

	# 1. Determine Type
	# (Rarity Mod could shift these weights if you wanted!)
	# For now, we'll keep type selection standard.
	if roll > (1.0 - CHANCE_EQ): type = LootType.EQUIPMENT
	elif roll > (1.0 - CHANCE_EQ - CHANCE_COMP): type = LootType.COMPONENT
	elif roll > (1.0 - CHANCE_EQ - CHANCE_COMP - CHANCE_MAT): type = LootType.MATERIAL

	# 2. Generate Data
	return _generate_data(type, tier, rarity_mod)

func _generate_data(type: int, tier: int, rarity_mod: int) -> Dictionary:
	var data = { "type": type, "tier": tier, "rarity": rarity_mod }

	var color_val = COLOR_COMMON
	match rarity_mod:
		1: color_val = COLOR_UNCOMMON
		2: color_val = COLOR_RARE
		3: color_val = COLOR_EPIC

	data["color_html"] = color_val.to_html()

	match type:
		LootType.BITS:
			# Rarity Mod impacts Quantity
			# 0=100%, 1=150%, 2=200%
			var mult = 1.0 + (0.5 * rarity_mod)
			var base = 50 * tier
			data["amount"] = roundi(base * mult * randf_range(0.9, 1.1))
			data["label"] = "Bits"

		LootType.MATERIAL:
			# For now, simple Amount
			data["id"] = "mat_generic"
			data["amount"] = 1 + rarity_mod
			data["label"] = "Materials"

		LootType.COMPONENT:
			data["id"] = "comp_generic"
			data["amount"] = 1 + rarity_mod
			data["label"] = "Components"

		LootType.EQUIPMENT:
			# Rarity Mod impacts Item Rarity (Common/Rare/Epic)
			# This assumes ItemDatabase can fetch random by tier/rarity
			data["id"] = "gun_rifle_mk1" # Placeholder
			data["label"] = "Unknown Weapon"

	return data
