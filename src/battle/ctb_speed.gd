extends RefCounted
class_name CTBSpeed


const NORMALIZED_MEDIAN_SPEED := 100.0


static func scale_for(raw_speeds: Array) -> float:
	if raw_speeds.is_empty():
		return 1.0
	var speeds: Array[float] = []
	for value: Variant in raw_speeds:
		speeds.append(float(maxi(int(value), 1)))
	speeds.sort()
	var middle := floori(speeds.size() * 0.5)
	var median := speeds[middle]
	if speeds.size() % 2 == 0:
		median = (speeds[middle - 1] + speeds[middle]) * 0.5
	return NORMALIZED_MEDIAN_SPEED / median


static func normalize(raw_speed: int, battle_scale: float) -> int:
	return maxi(roundi(maxi(raw_speed, 1) * maxf(battle_scale, 0.0)), 1)


static func head_start_ct(ct_speed: int, roll: float) -> int:
	return roundi(maxi(ct_speed, 1) * 5.0 * clampf(roll, 0.0, 1.0))
