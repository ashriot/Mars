# LootManager.gd (Autoload)
extends Node

enum LootType { BITS, MATERIAL, COMPONENT, EQUIPMENT }

# Generic weighting
const CHANCE_BITS = 0.1
const CHANCE_MAT = 0.35
const CHANCE_COMP = 0.15
const CHANCE_EQ = 0.4

# --- DEFINE RARITY COLORS ---
const COLOR_COMMON = Color.LIGHT_SLATE_GRAY
const COLOR_UNCOMMON = Color.YELLOW_GREEN
const COLOR_RARE = Color.CADET_BLUE
const COLOR_EPIC = Color.MEDIUM_PURPLE

# --- PUBLIC API ---
# DungeonMap calls this during generate_hex_grid()
func roll_loot(tier: int, rarity_mod: int) -> Dictionary:
	var roll = randf()
	var type: int = LootType.BITS

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
			var mult = 1.0 + (0.5 * rarity_mod)
			var base = 50 * tier
			data["amount"] = roundi(base * mult * randf_range(0.9, 1.1))
			# Bits are not in ItemDatabase, so we DO need a label here.
			data["label"] = "Bits"

		LootType.MATERIAL:
			# Format: mat_weap_1
			var type_str = "weap" if randf() > 0.5 else "arm"
			var id = "mat_%s_%d" % [type_str, tier]
			var amount = 1 + rarity_mod + int(randf() * rarity_mod)

			data["id"] = id
			data["amount"] = amount
			# No label needed

		LootType.COMPONENT:
			# Format: comp_arm_3_common
			var comp_tier = max(2, tier)
			var type_str = "weap" if randf() > 0.5 else "arm"
			var rarity_str = "common"

			if rarity_mod >= 2 and randf() > 0.5:
				rarity_str = "rare"

			var id = "comp_%s_%d_%s" % [type_str, comp_tier, rarity_str]

			data["id"] = id
			data["amount"] = 1
			# No label needed

		LootType.EQUIPMENT:
			# 1. Pick a random base item
			var eq_id = ItemDatabase.get_random_equipment_id()
			data["id"] = eq_id

			# 2. Calculate Drop Tier
			# Usually matches dungeon tier, maybe -1 for bad luck
			# Clamp between 1 and 5
			var drop_tier = clampi(tier, 1, 5)

			# 3. Calculate Drop Rank
			# Start at the bottom of the tier? Or randomized?
			# Tier 1: Rank 1-4. Tier 2: Rank 5-8.
			# Formula: ((Tier - 1) * 4) + Random(1, 3)
			var min_rank = ((drop_tier - 1) * 4) + 1
			var added_rank = randi_range(0, 2) + rarity_mod # Rarity boosts rank!
			var drop_rank = clampi(min_rank + added_rank, 1, 20)

			# 4. Save parameters to data
			data["drop_tier"] = drop_tier
			data["drop_rank"] = drop_rank

			# 5. Look up name for the UI label
			data["label"] = ItemDatabase.get_item_name(eq_id)

	return data
