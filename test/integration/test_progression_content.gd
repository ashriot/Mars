extends GutTest

const CONTENT_ROOT := "res://data/progression/"
const EXPECTED := {
	"gun": {"hero":"asher", "nodes":18, "xp":13900, "effects":{"stat":15,"action":2,"passive":1,"shift_action":0}},
	"snp": {"hero":"asher", "nodes":8, "xp":3300, "effects":{"stat":6,"action":2,"passive":0,"shift_action":0}},
	"opr": {"hero":"asher", "nodes":1, "xp":100, "effects":{"stat":0,"action":1,"passive":0,"shift_action":0}},
	"kin": {"hero":"echo", "nodes":17, "xp":12550, "effects":{"stat":14,"action":3,"passive":0,"shift_action":0}},
	"psi": {"hero":"echo", "nodes":18, "xp":13150, "effects":{"stat":15,"action":3,"passive":0,"shift_action":0}},
	"dom": {"hero":"echo", "nodes":1, "xp":100, "effects":{"stat":0,"action":1,"passive":0,"shift_action":0}},
	"med": {"hero":"sands", "nodes":6, "xp":2100, "effects":{"stat":0,"action":4,"passive":1,"shift_action":1}},
	"stg": {"hero":"sands", "nodes":6, "xp":2100, "effects":{"stat":0,"action":4,"passive":1,"shift_action":1}},
	"van": {"hero":"sands", "nodes":6, "xp":2100, "effects":{"stat":0,"action":4,"passive":1,"shift_action":1}},
}

# Stable IDs are authored semantic names: role.root, then reward/resource names;
# repeated stat rewards receive a deterministic numeric suffix.
const EXPECTED_IDS := {
	"gun": ["gun.root","gun.atk_1","gun.hp_5","gun.hp_10","gun.hp_10_2","gun.spd_1","gun.fusion_ammo","gun.psy_1","gun.hp_5_2","gun.hp_10_3","gun.spd_1_2","gun.atk_1_2","gun.atk_2","gun.atk_2_2","gun.bullet_time","gun.spd_2","gun.spd_2_2","gun.psy_2"],
	"snp": ["snp.root","snp.hp_5","snp.atk_1","snp.atk_2","snp.atk_2_2","snp.aim_1","snp.ovr_1","snp.aimed_shot"],
	"opr": ["opr.root"],
	"kin": ["kin.root","kin.hp_5","kin.psy_1","kin.psy_2","kin.psy_2_2","kin.spd_1","kin.rejuvenate","kin.atk_1","kin.hp_10","kin.hp_10_2","kin.spd_1_2","kin.psy_1_2","kin.psy_2_3","kin.psy_2_4","kin.pain_transfer","kin.spd_2","kin.atk_2"],
	"psi": ["psi.root","psi.hp_5","psi.atk_1","psi.atk_2","psi.atk_2_2","psi.ovr_1","psi.energy_barrier","psi.psy_1","psi.hp_5_2","psi.hp_10","psi.ovr_1_2","psi.atk_1_2","psi.atk_2_3","psi.atk_2_4","psi.reverberate","psi.ovr_2","psi.psy_2","psi.ovr_2_2"],
	"dom": ["dom.root"],
	"med": ["med.root","med.booster_shots","med.auto_shields","med.bastion","med.triage","med.apply_painkillers"],
	"stg": ["stg.root","stg.gambit","stg.advantage","stg.checkmate","stg.opening_move","stg.fianchetto"],
	"van": ["van.root","van.overwatch","van.focus_fire","van.phalanx","van.return_fire","van.opening_salvo"],
}

func test_every_production_role_is_valid_and_matches_authored_summary() -> void:
	for role_id: String in EXPECTED:
		var expected: Dictionary = EXPECTED[role_id]
		var path := CONTENT_ROOT.path_join(expected.hero).path_join(role_id + ".json")
		var result := ProgressionJsonLoader.load_file(path)
		assert_eq(result.errors.size(), 0, path)
		assert_not_null(result.tree, path)
		if result.tree == null: continue
		assert_eq(result.tree.role_id, role_id)
		assert_eq(result.tree.root_id, role_id + ".root")
		assert_eq(result.tree.nodes.map(func(node): return node.id), EXPECTED_IDS[role_id])
		var catalog := ProgressionCatalog.from_validated_trees([result.tree])
		var summary := catalog.get_summary(role_id)
		assert_eq(summary.node_count, expected.nodes, role_id)
		assert_eq(summary.total_xp, expected.xp, role_id)
		assert_eq(summary.effect_counts, expected.effects, role_id)

func test_all_non_stat_rewards_reference_explicit_action_resources() -> void:
	for role_id: String in EXPECTED:
		var expected: Dictionary = EXPECTED[role_id]
		var result := ProgressionJsonLoader.load_file(CONTENT_ROOT.path_join(expected.hero).path_join(role_id + ".json"))
		if result.tree == null: continue
		for node: ProgressionNodeDefinition in result.tree.nodes:
			if node.effect.type != ProgressionEffect.Type.STAT:
				assert_true(node.effect.target.begins_with("res://data/heroes/"), node.id)
				assert_true(ResourceLoader.exists(node.effect.target), node.id)
				assert_true(ResourceLoader.load(node.effect.target) is Action, node.id)

func test_confirmed_single_root_roles_are_explicit_approved_baselines() -> void:
	_assert_single_action_root("opr", "asher", "res://data/heroes/asher/actions/coordinate.tres")
	_assert_single_action_root("dom", "echo", "res://data/heroes/echo/actions/displace.tres")

func test_catalog_recursively_loads_all_nine_production_roles() -> void:
	var catalog := ProgressionCatalog.new()
	assert_eq(catalog.load_directory(CONTENT_ROOT), OK)
	var actual_ids := catalog.role_ids
	var expected_ids := Array(EXPECTED.keys(), TYPE_STRING, "", null)
	actual_ids.sort()
	expected_ids.sort()
	assert_eq(actual_ids, expected_ids)

func test_role_definition_references_authoritative_json_role_id() -> void:
	var role := RoleDefinition.new()
	role.role_id = "gun"
	assert_eq(role.role_id, "gun")

func test_progression_system_publishes_complete_catalog_and_service() -> void:
	var system := get_node_or_null("/root/ProgressionSystem")
	assert_not_null(system)
	if system == null: return
	assert_not_null(system.catalog)
	assert_not_null(system.service)
	var actual_ids: Array[String] = system.catalog.role_ids
	var expected_ids := Array(EXPECTED.keys(), TYPE_STRING, "", null)
	actual_ids.sort()
	expected_ids.sort()
	assert_eq(actual_ids, expected_ids)

func test_party_menu_uses_startup_progression_dependencies_by_default() -> void:
	var system := get_node_or_null("/root/ProgressionSystem")
	var menu := PartyMenu.new()
	assert_not_null(system)
	if system == null: return
	assert_true(is_same(menu.progression_catalog, system.catalog))
	assert_true(is_same(menu.progression_service, system.service))
	menu.free()

func test_new_progression_consumers_never_access_legacy_role_topology() -> void:
	for root in ["res://src/progression", "res://src/hub"]:
		_assert_no_legacy_topology_access(root)

func test_production_content_has_no_legacy_progression_references() -> void:
	var forbidden := [
		"RoleNode", "root_node", "init_structure", "generated_id",
		"calculated_xp_cost", "unlock_node(",
		"spend_xp(", "_process_node_stats", "_bake_tree_into_role",
		"role_node.gd", "uid://cuhoaxfyipk6s",
	]
	for root in ["res://src", "res://data"]:
		_assert_tree_excludes_tokens(root, forbidden)
	_assert_file_excludes_tokens("res://project.godot", forbidden)
	assert_false(FileAccess.file_exists("res://src/scripts/data/role_node.gd"))
	assert_true(_is_legacy_nested_role_resource("res://data/heroes/new_hero/roles/new_role/node.tres"))
	assert_false(_is_legacy_nested_role_resource("res://data/heroes/new_hero/roles/new_role.tres"))

func _assert_single_action_root(role_id: String, hero_id: String, resource_path: String) -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTENT_ROOT.path_join(hero_id).path_join(role_id + ".json")))
	_assert_node_arrays_match(document.nodes, [{"column":0, "effect":{"resource":resource_path, "slot":1, "type":"action"}, "id":role_id + ".root", "parent":null, "rank":1, "xp_cost":100}], role_id)

func _assert_node_arrays_match(actual_nodes: Array, expected_nodes: Array, role_id: String) -> void:
	assert_eq(actual_nodes.size(), expected_nodes.size(), role_id)
	for index in mini(actual_nodes.size(), expected_nodes.size()):
		var actual: Dictionary = actual_nodes[index]
		var expected: Dictionary = expected_nodes[index]
		var context := "%s node %d (%s)" % [role_id, index, expected.id]
		assert_eq(str(actual.id), str(expected.id), context)
		assert_eq(actual.parent, expected.parent, context)
		assert_eq(int(actual.rank), int(expected.rank), context)
		assert_eq(int(actual.column), int(expected.column), context)
		assert_eq(int(actual.xp_cost), int(expected.xp_cost), context)
		assert_eq(str(actual.effect.type), str(expected.effect.type), context)
		match str(expected.effect.type):
			"stat":
				assert_eq(str(actual.effect.stat), str(expected.effect.stat), context)
				assert_eq(int(actual.effect.amount), int(expected.effect.amount), context)
			"action":
				assert_eq(str(actual.effect.resource), str(expected.effect.resource), context)
				assert_eq(int(actual.effect.slot), int(expected.effect.slot), context)
			"passive", "shift_action":
				assert_eq(str(actual.effect.resource), str(expected.effect.resource), context)

func _assert_no_legacy_topology_access(root: String) -> void:
	var directory := DirAccess.open(root)
	assert_not_null(directory, root)
	if directory == null: return
	for filename: String in directory.get_files():
		if filename.get_extension() == "gd":
			var source := FileAccess.get_file_as_string(root.path_join(filename))
			assert_false("root_node" in source, root.path_join(filename))
			assert_false("init_structure" in source, root.path_join(filename))
	for child: String in directory.get_directories():
		_assert_no_legacy_topology_access(root.path_join(child))

func _assert_tree_excludes_tokens(root: String, forbidden: Array) -> void:
	var directory := DirAccess.open(root)
	assert_not_null(directory, root)
	if directory == null: return
	for filename: String in directory.get_files():
		var path := root.path_join(filename)
		if _is_legacy_nested_role_resource(path):
			fail_test("Legacy nested role resource remains: %s" % path)
		if filename.get_extension().to_lower() in ["gd", "tscn", "tres", "res", "godot", "cfg", "import", "remap"]:
			_assert_file_excludes_tokens(path, forbidden)
	for child: String in directory.get_directories():
		_assert_tree_excludes_tokens(root.path_join(child), forbidden)

func _assert_file_excludes_tokens(path: String, forbidden: Array) -> void:
	var source := FileAccess.get_file_as_string(path)
	for token: String in forbidden:
		assert_false(token in source, "%s contains %s" % [path, token])

func _is_legacy_nested_role_resource(path: String) -> bool:
	if path.get_extension().to_lower() != "tres":
		return false
	var normalized := path.trim_prefix("res://")
	var parts := normalized.split("/")
	var roles_index := Array(parts).find("roles")
	return roles_index >= 0 and roles_index + 2 < parts.size()
