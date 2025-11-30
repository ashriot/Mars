extends Resource
class_name UpgradeMaterial

enum MaterialType { WEAPON, ARMOR }

@export var material_name: String = ""
@export var type: MaterialType = MaterialType.WEAPON
@export_range(1, 5) var tier: int = 1

func get_xp_value() -> int:
	return 10 * int(pow(2, tier - 1))
