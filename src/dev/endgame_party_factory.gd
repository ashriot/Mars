extends RefCounted
class_name EndgamePartyFactory

enum EquipmentPreset {
	SKILLS_ONLY,
	MAX_EQUIPMENT,
}

const HERO_PATHS: Array[String] = [
	"res://data/heroes/asher/asher.tres",
	"res://data/heroes/echo/echo.tres",
	"res://data/heroes/sands/sands.tres",
]


class BuildResult extends RefCounted:
	var success: bool
	var error: String
	var roster: Array[HeroData] = []

	func _init(ok: bool, message: String = "", heroes: Array[HeroData] = []) -> void:
		success = ok
		error = message
		roster.assign(heroes)


static func build(catalog: ProgressionCatalog, preset: int) -> BuildResult:
	if catalog == null:
		return BuildResult.new(false, "A progression catalog is required.")
	if preset < EquipmentPreset.SKILLS_ONLY or preset > EquipmentPreset.MAX_EQUIPMENT:
		return BuildResult.new(false, "Unknown equipment preset %d." % preset)

	var roster: Array[HeroData] = []
	for path: String in HERO_PATHS:
		var source := load(path) as HeroData
		if source == null:
			return BuildResult.new(false, "Could not load hero at %s." % path)
		var hero := source.duplicate(true) as HeroData
		if hero == null:
			return BuildResult.new(false, "Could not duplicate hero at %s." % path)

		hero.unlocked_role_ids.clear()
		for definition: RoleDefinition in hero.role_definitions:
			hero.unlocked_role_ids.append(definition.role_id)
		hero.role_progress.clear()
		hero.injuries = 0
		hero.boon_focused = false
		hero.boon_armored = false

		for role_id: String in hero.unlocked_role_ids:
			var tree := catalog.get_role(role_id)
			if tree == null:
				return BuildResult.new(false, "Missing progression tree '%s'." % role_id)
			var owned: Array[String] = []
			var paid: Dictionary[String, int] = {}
			for node: ProgressionNodeDefinition in tree.nodes:
				if node.is_structural:
					continue
				owned.append(node.id)
				paid[node.id] = 0
			hero.role_progress[role_id] = HeroRoleProgress.new(tree.version, owned, paid)

		if hero.weapon != null:
			hero.weapon = hero.weapon.duplicate(true) as Equipment
		if hero.armor != null:
			hero.armor = hero.armor.duplicate(true) as Equipment
		if preset == EquipmentPreset.MAX_EQUIPMENT:
			for equipment: Equipment in [hero.weapon, hero.armor]:
				if equipment == null:
					continue
				equipment.tier = 5
				equipment.rank = 30
				equipment.current_xp = 0

		var rebuild := ProgressionRebuilder.new(catalog).rebuild(hero)
		if not rebuild.success:
			return BuildResult.new(false, "%s: %s" % [hero.hero_id, rebuild.error])
		roster.append(hero)

	return BuildResult.new(true, "", roster)
