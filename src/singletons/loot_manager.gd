# LootManager.gd (Autoload)
extends Node

enum LootType { BITS, MATERIAL, COMPONENT, EQUIPMENT, MOD }

# --- CONFIGURATION ---
const CHANCE_MATERIAL: float = 0.3
const CHANCE_BITS: float = 0.2
const CHANCE_COMPONENT: float = 0.1
const CHANCE_MOD: float = 0.4

# --- DEFINE RARITY COLORS ---
const COLOR_COMMON = Color.LIGHT_SLATE_GRAY
const COLOR_UNCOMMON = Color.YELLOW_GREEN
const COLOR_RARE = Color.CADET_BLUE
const COLOR_EPIC = Color.MEDIUM_PURPLE

func roll_loot(tier: int, rarity_mod: int) -> Dictionary:
	var roll = randf()
	var type = LootType.BITS

	if roll > (1.0 - CHANCE_MOD):
		type = LootType.MOD
	elif roll > (1.0 - CHANCE_MOD - CHANCE_COMPONENT):
		type = LootType.COMPONENT
	elif roll > (1.0 - CHANCE_MOD - CHANCE_COMPONENT - CHANCE_MATERIAL):
		type = LootType.MATERIAL

	return _generate_loot_data(type, tier, rarity_mod)

func _generate_loot_data(type: int, tier: int, rarity_mod: int) -> Dictionary:
	var data = { "type": type, "tier": tier, "rarity": rarity_mod }

	var color_val = COLOR_COMMON
	match rarity_mod:
		1: color_val = COLOR_UNCOMMON
		2: color_val = COLOR_RARE
		3: color_val = COLOR_EPIC

	data["color_html"] = color_val.to_html()

	match type:
		LootType.BITS:
			var mult = 1.0 + (0.5 * rarity_mod)
			var base = 50 * tier
			data["amount"] = roundi(base * mult * randf_range(0.8, 1.2))
			data["label"] = "Bits"

		LootType.MATERIAL:
			var type_str = "weap" if randf() > 0.5 else "arm"
			var id = "mat_%s_%d" % [type_str, tier]
			var amount = (1 + rarity_mod) * 2 + int(randf() * (2 + rarity_mod) * 2)

			data["id"] = id
			data["amount"] = amount

		LootType.COMPONENT:
			var comp_tier = max(1, tier)
			var type_str = "weap" if randf() > 0.5 else "arm"
			var rarity_str = "common"
			if rarity_mod >= 2 and randf() > 0.75:
				rarity_str = "rare"

			var id = "comp_%s_%d_%s" % [type_str, comp_tier, rarity_str]

			data["id"] = id
			data["amount"] = 1
			# Label filled by GameManager lookup

		LootType.MOD:
			var mod_id = ItemDatabase.get_random_mod_id()
			data["id"] = mod_id
			data["amount"] = 1
			data["label"] = ItemDatabase.get_item_name(mod_id)

		LootType.EQUIPMENT:
			# Only used if manually called, not by random roll
			data["id"] = "gun_rifle_mk1"
			data["amount"] = 1

	return data
