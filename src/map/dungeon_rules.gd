extends RefCounted
class_name DungeonRules

const MIN_DUNGEON_TIER := 1
const MIN_TERMINALS := 2


static func normalized_tier(tier: int) -> int:
	return max(MIN_DUNGEON_TIER, tier)


static func loot_scalar(tier: int) -> float:
	return 1.0 + (normalized_tier(tier) - MIN_DUNGEON_TIER) * 0.25


static func calculate_count(map_size: int, density_percent: float, multiplier: float) -> int:
	return max(0, int(map_size * density_percent / 100.0 * multiplier))


static func apply_minimum(value: int, minimum: int) -> int:
	return max(value, minimum)


static func actionable_total(counts: Dictionary, has_boss: bool) -> int:
	var total := 0
	for count in counts.values():
		total += int(count)
	return total + int(has_boss)
