extends GutTest

const CONTENT_ROOT := "res://data/progression/"
const STARTING_KITS := {
	"gun": ["double_tap.tres", "fusion_ammo.tres"],
	"opr": ["coordinate.tres", "decoy.tres"],
	"snp": ["mark_target.tres", "aimed_shot.tres"],
	"dom": ["displace.tres", "feedback.tres"],
	"kin": ["telekinesis.tres", "rejuvenate.tres"],
	"psi": ["focused_bolt.tres", "energy_barrier.tres"],
	"med": ["first_aid.tres", "booster_shots.tres"],
	"stg": ["tempo.tres", "gambit.tres"],
	"van": ["draw_fire.tres", "overwatch.tres"],
}
const EXPECTED := {
	"gun": {"hero":"asher", "nodes":19, "xp":11900, "effects":{"stat":15,"action":2,"passive":1,"shift_action":0}},
	"snp": {"hero":"asher", "nodes":9, "xp":2700, "effects":{"stat":6,"action":2,"passive":0,"shift_action":0}},
	"opr": {"hero":"asher", "nodes":4, "xp":200, "effects":{"stat":1,"action":2,"passive":0,"shift_action":0}},
	"kin": {"hero":"echo", "nodes":18, "xp":10700, "effects":{"stat":14,"action":3,"passive":0,"shift_action":0}},
	"psi": {"hero":"echo", "nodes":19, "xp":11300, "effects":{"stat":15,"action":3,"passive":0,"shift_action":0}},
	"dom": {"hero":"echo", "nodes":4, "xp":200, "effects":{"stat":1,"action":2,"passive":0,"shift_action":0}},
	"med": {"hero":"sands", "nodes":7, "xp":1400, "effects":{"stat":0,"action":4,"passive":1,"shift_action":1}},
	"stg": {"hero":"sands", "nodes":7, "xp":1400, "effects":{"stat":0,"action":4,"passive":1,"shift_action":1}},
	"van": {"hero":"sands", "nodes":7, "xp":1400, "effects":{"stat":0,"action":4,"passive":1,"shift_action":1}},
}

# Stable IDs are authored semantic names: role.root, then reward/resource names;
# repeated stat rewards receive a deterministic numeric suffix.
# Independently authored compact node rows:
# [id, parent, rank, column, xp_cost, node_kind, starting_owned, exact_effect]
const AUTHORED_NODES := {
"gun": [
	["gun.anchor", null, 1, 0, null, "role_anchor", false, null],
	["gun.root", "gun.anchor", 1, -1, 0, "progression", true, {"resource":"res://data/heroes/asher/actions/double_tap.tres","slot":1,"type":"action"}],
	["gun.fusion_ammo", "gun.anchor", 1, 1, 0, "progression", true, {"resource":"res://data/heroes/asher/actions/fusion_ammo.tres","slot":2,"type":"action"}],
	["gun.atk_1", "gun.anchor", 2, 0, 200, "progression", false, {"amount":1,"stat":"ATK","type":"stat"}],
	["gun.hp_5", "gun.atk_1", 3, 0, 300, "progression", false, {"amount":5,"stat":"HP","type":"stat"}],
	["gun.hp_10", "gun.hp_5", 3, -1, 450, "progression", false, {"amount":10,"stat":"HP","type":"stat"}],
	["gun.hp_10_2", "gun.hp_10", 4, -1, 600, "progression", false, {"amount":10,"stat":"HP","type":"stat"}],
	["gun.spd_1", "gun.hp_5", 4, 0, 400, "progression", false, {"amount":1,"stat":"SPD","type":"stat"}],
	["gun.psy_1", "gun.spd_1", 5, 0, 500, "progression", false, {"amount":1,"stat":"PSY","type":"stat"}],
	["gun.hp_5_2", "gun.psy_1", 6, 0, 600, "progression", false, {"amount":5,"stat":"HP","type":"stat"}],
	["gun.hp_10_3", "gun.hp_5_2", 6, -1, 900, "progression", false, {"amount":10,"stat":"HP","type":"stat"}],
	["gun.spd_1_2", "gun.hp_5_2", 7, 0, 700, "progression", false, {"amount":1,"stat":"SPD","type":"stat"}],
	["gun.atk_1_2", "gun.spd_1_2", 8, 0, 800, "progression", false, {"amount":1,"stat":"ATK","type":"stat"}],
	["gun.atk_2", "gun.atk_1_2", 8, -1, 1200, "progression", false, {"amount":2,"stat":"ATK","type":"stat"}],
	["gun.atk_2_2", "gun.atk_2", 9, -1, 1350, "progression", false, {"amount":2,"stat":"ATK","type":"stat"}],
	["gun.bullet_time", "gun.atk_1_2", 9, 0, 900, "progression", false, {"resource":"res://data/heroes/asher/actions/bullet_time.tres","type":"passive"}],
	["gun.spd_2", "gun.spd_1_2", 7, 1, 1050, "progression", false, {"amount":2,"stat":"SPD","type":"stat"}],
	["gun.spd_2_2", "gun.spd_2", 8, 1, 1200, "progression", false, {"amount":2,"stat":"SPD","type":"stat"}],
	["gun.psy_2", "gun.psy_1", 5, 1, 750, "progression", false, {"amount":2,"stat":"PSY","type":"stat"}],
],
"opr": [
	["opr.anchor", null, 1, 0, null, "role_anchor", false, null],
	["opr.root", "opr.anchor", 1, -1, 0, "progression", true, {"resource":"res://data/heroes/asher/actions/coordinate.tres","slot":1,"type":"action"}],
	["opr.decoy", "opr.anchor", 1, 1, 0, "progression", true, {"resource":"res://data/heroes/asher/actions/decoy.tres","slot":2,"type":"action"}],
	["opr.hp_5", "opr.anchor", 2, 0, 200, "progression", false, {"amount":5,"stat":"HP","type":"stat"}],
],
"snp": [
	["snp.anchor", null, 1, 0, null, "role_anchor", false, null],
	["snp.root", "snp.anchor", 1, -1, 0, "progression", true, {"resource":"res://data/heroes/asher/actions/mark_target.tres","slot":1,"type":"action"}],
	["snp.aimed_shot", "snp.anchor", 1, 1, 0, "progression", true, {"resource":"res://data/heroes/asher/actions/aimed_shot.tres","slot":2,"type":"action"}],
	["snp.hp_5", "snp.anchor", 2, 0, 200, "progression", false, {"amount":5,"stat":"HP","type":"stat"}],
	["snp.atk_1", "snp.hp_5", 3, 0, 300, "progression", false, {"amount":1,"stat":"ATK","type":"stat"}],
	["snp.atk_2", "snp.atk_1", 3, -1, 450, "progression", false, {"amount":2,"stat":"ATK","type":"stat"}],
	["snp.atk_2_2", "snp.atk_2", 4, -1, 600, "progression", false, {"amount":2,"stat":"ATK","type":"stat"}],
	["snp.aim_1", "snp.atk_2_2", 5, -1, 750, "progression", false, {"amount":1,"stat":"AIM","type":"stat"}],
	["snp.ovr_1", "snp.atk_1", 4, 0, 400, "progression", false, {"amount":1,"stat":"OVR","type":"stat"}],
],
"dom": [
	["dom.anchor", null, 1, 0, null, "role_anchor", false, null],
	["dom.root", "dom.anchor", 1, -1, 0, "progression", true, {"resource":"res://data/heroes/echo/actions/displace.tres","slot":1,"type":"action"}],
	["dom.feedback", "dom.anchor", 1, 1, 0, "progression", true, {"resource":"res://data/heroes/echo/actions/feedback.tres","slot":2,"type":"action"}],
	["dom.psy_1", "dom.anchor", 2, 0, 200, "progression", false, {"amount":1,"stat":"PSY","type":"stat"}],
],
"kin": [
	["kin.anchor", null, 1, 0, null, "role_anchor", false, null],
	["kin.root", "kin.anchor", 1, -1, 0, "progression", true, {"resource":"res://data/heroes/echo/actions/telekinesis.tres","slot":1,"type":"action"}],
	["kin.rejuvenate", "kin.anchor", 1, 1, 0, "progression", true, {"resource":"res://data/heroes/echo/actions/rejuvenate.tres","slot":2,"type":"action"}],
	["kin.hp_5", "kin.anchor", 2, 0, 200, "progression", false, {"amount":5,"stat":"HP","type":"stat"}],
	["kin.psy_1", "kin.hp_5", 3, 0, 300, "progression", false, {"amount":1,"stat":"PSY","type":"stat"}],
	["kin.psy_2", "kin.psy_1", 3, -1, 450, "progression", false, {"amount":2,"stat":"PSY","type":"stat"}],
	["kin.psy_2_2", "kin.psy_2", 4, -1, 600, "progression", false, {"amount":2,"stat":"PSY","type":"stat"}],
	["kin.spd_1", "kin.psy_1", 4, 0, 400, "progression", false, {"amount":1,"stat":"SPD","type":"stat"}],
	["kin.atk_1", "kin.spd_1", 5, 0, 500, "progression", false, {"amount":1,"stat":"ATK","type":"stat"}],
	["kin.hp_10", "kin.atk_1", 6, 0, 600, "progression", false, {"amount":10,"stat":"HP","type":"stat"}],
	["kin.hp_10_2", "kin.hp_10", 6, -1, 900, "progression", false, {"amount":10,"stat":"HP","type":"stat"}],
	["kin.spd_1_2", "kin.hp_10", 7, 0, 700, "progression", false, {"amount":1,"stat":"SPD","type":"stat"}],
	["kin.psy_1_2", "kin.spd_1_2", 8, 0, 800, "progression", false, {"amount":1,"stat":"PSY","type":"stat"}],
	["kin.psy_2_3", "kin.psy_1_2", 8, -1, 1200, "progression", false, {"amount":2,"stat":"PSY","type":"stat"}],
	["kin.psy_2_4", "kin.psy_2_3", 9, -1, 1350, "progression", false, {"amount":2,"stat":"PSY","type":"stat"}],
	["kin.pain_transfer", "kin.psy_1_2", 9, 0, 900, "progression", false, {"resource":"res://data/heroes/echo/actions/pain_transfer.tres","slot":3,"type":"action"}],
	["kin.spd_2", "kin.spd_1_2", 7, 1, 1050, "progression", false, {"amount":2,"stat":"SPD","type":"stat"}],
	["kin.atk_2", "kin.atk_1", 5, 1, 750, "progression", false, {"amount":2,"stat":"ATK","type":"stat"}],
],
"psi": [
	["psi.anchor", null, 1, 0, null, "role_anchor", false, null],
	["psi.root", "psi.anchor", 1, -1, 0, "progression", true, {"resource":"res://data/heroes/echo/actions/focused_bolt.tres","slot":1,"type":"action"}],
	["psi.energy_barrier", "psi.anchor", 1, 1, 0, "progression", true, {"resource":"res://data/heroes/echo/actions/energy_barrier.tres","slot":2,"type":"action"}],
	["psi.hp_5", "psi.anchor", 2, 0, 200, "progression", false, {"amount":5,"stat":"HP","type":"stat"}],
	["psi.atk_1", "psi.hp_5", 3, 0, 300, "progression", false, {"amount":1,"stat":"ATK","type":"stat"}],
	["psi.atk_2", "psi.atk_1", 3, -1, 450, "progression", false, {"amount":2,"stat":"ATK","type":"stat"}],
	["psi.atk_2_2", "psi.atk_2", 4, -1, 600, "progression", false, {"amount":2,"stat":"ATK","type":"stat"}],
	["psi.ovr_1", "psi.atk_1", 4, 0, 400, "progression", false, {"amount":1,"stat":"OVR","type":"stat"}],
	["psi.psy_1", "psi.ovr_1", 5, 0, 500, "progression", false, {"amount":1,"stat":"PSY","type":"stat"}],
	["psi.hp_5_2", "psi.psy_1", 6, 0, 600, "progression", false, {"amount":5,"stat":"HP","type":"stat"}],
	["psi.hp_10", "psi.hp_5_2", 6, -1, 900, "progression", false, {"amount":10,"stat":"HP","type":"stat"}],
	["psi.ovr_1_2", "psi.hp_5_2", 7, 0, 700, "progression", false, {"amount":1,"stat":"OVR","type":"stat"}],
	["psi.atk_1_2", "psi.ovr_1_2", 8, 0, 800, "progression", false, {"amount":1,"stat":"ATK","type":"stat"}],
	["psi.atk_2_3", "psi.atk_1_2", 8, -1, 1200, "progression", false, {"amount":2,"stat":"ATK","type":"stat"}],
	["psi.atk_2_4", "psi.atk_2_3", 9, -1, 1350, "progression", false, {"amount":2,"stat":"ATK","type":"stat"}],
	["psi.reverberate", "psi.atk_1_2", 9, 0, 900, "progression", false, {"resource":"res://data/heroes/echo/actions/reverberate.tres","slot":3,"type":"action"}],
	["psi.ovr_2", "psi.ovr_1_2", 7, 1, 1050, "progression", false, {"amount":2,"stat":"OVR","type":"stat"}],
	["psi.psy_2", "psi.psy_1", 5, 1, 750, "progression", false, {"amount":2,"stat":"PSY","type":"stat"}],
	["psi.ovr_2_2", "psi.ovr_1", 4, 1, 600, "progression", false, {"amount":2,"stat":"OVR","type":"stat"}],
],
"med": [
	["med.anchor", null, 1, 0, null, "role_anchor", false, null],
	["med.root", "med.anchor", 1, -1, 0, "progression", true, {"resource":"res://data/heroes/sands/actions/first_aid.tres","slot":1,"type":"action"}],
	["med.booster_shots", "med.anchor", 1, 1, 0, "progression", true, {"resource":"res://data/heroes/sands/actions/booster_shots.tres","slot":2,"type":"action"}],
	["med.auto_shields", "med.anchor", 2, 0, 200, "progression", false, {"resource":"res://data/heroes/sands/actions/auto_shields.tres","slot":3,"type":"action"}],
	["med.bastion", "med.auto_shields", 3, 0, 300, "progression", false, {"resource":"res://data/heroes/sands/actions/bastion.tres","slot":4,"type":"action"}],
	["med.triage", "med.bastion", 4, 0, 400, "progression", false, {"resource":"res://data/heroes/sands/actions/triage.tres","type":"shift_action"}],
	["med.apply_painkillers", "med.triage", 5, 0, 500, "progression", false, {"resource":"res://data/heroes/sands/actions/apply_painkillers.tres","type":"passive"}],
],
"stg": [
	["stg.anchor", null, 1, 0, null, "role_anchor", false, null],
	["stg.root", "stg.anchor", 1, -1, 0, "progression", true, {"resource":"res://data/heroes/sands/actions/tempo.tres","slot":1,"type":"action"}],
	["stg.gambit", "stg.anchor", 1, 1, 0, "progression", true, {"resource":"res://data/heroes/sands/actions/gambit.tres","slot":2,"type":"action"}],
	["stg.advantage", "stg.anchor", 2, 0, 200, "progression", false, {"resource":"res://data/heroes/sands/actions/advantage.tres","slot":3,"type":"action"}],
	["stg.checkmate", "stg.advantage", 3, 0, 300, "progression", false, {"resource":"res://data/heroes/sands/actions/checkmate.tres","slot":4,"type":"action"}],
	["stg.opening_move", "stg.checkmate", 4, 0, 400, "progression", false, {"resource":"res://data/heroes/sands/actions/opening_move.tres","type":"shift_action"}],
	["stg.fianchetto", "stg.opening_move", 5, 0, 500, "progression", false, {"resource":"res://data/heroes/sands/actions/fianchetto.tres","type":"passive"}],
],
"van": [
	["van.anchor", null, 1, 0, null, "role_anchor", false, null],
	["van.root", "van.anchor", 1, -1, 0, "progression", true, {"resource":"res://data/heroes/sands/actions/draw_fire.tres","slot":1,"type":"action"}],
	["van.overwatch", "van.anchor", 1, 1, 0, "progression", true, {"resource":"res://data/heroes/sands/actions/overwatch.tres","slot":2,"type":"action"}],
	["van.focus_fire", "van.anchor", 2, 0, 200, "progression", false, {"resource":"res://data/heroes/sands/actions/focus_fire.tres","slot":3,"type":"action"}],
	["van.phalanx", "van.focus_fire", 3, 0, 300, "progression", false, {"resource":"res://data/heroes/sands/actions/phalanx.tres","slot":4,"type":"action"}],
	["van.return_fire", "van.phalanx", 4, 0, 400, "progression", false, {"resource":"res://data/heroes/sands/actions/return_fire.tres","type":"passive"}],
	["van.opening_salvo", "van.return_fire", 5, 0, 500, "progression", false, {"resource":"res://data/heroes/sands/actions/opening_salvo.tres","type":"shift_action"}],
],
}
const FIRST_PAID := {
	"gun": ["gun.atk_1", {"amount":1, "stat":"ATK", "type":"stat"}],
	"opr": ["opr.hp_5", {"amount":5, "stat":"HP", "type":"stat"}],
	"snp": ["snp.hp_5", {"amount":5, "stat":"HP", "type":"stat"}],
	"dom": ["dom.psy_1", {"amount":1, "stat":"PSY", "type":"stat"}],
	"kin": ["kin.hp_5", {"amount":5, "stat":"HP", "type":"stat"}],
	"psi": ["psi.hp_5", {"amount":5, "stat":"HP", "type":"stat"}],
	"med": ["med.auto_shields", {"resource":"res://data/heroes/sands/actions/auto_shields.tres", "slot":3, "type":"action"}],
	"stg": ["stg.advantage", {"resource":"res://data/heroes/sands/actions/advantage.tres", "slot":3, "type":"action"}],
	"van": ["van.focus_fire", {"resource":"res://data/heroes/sands/actions/focus_fire.tres", "slot":3, "type":"action"}],
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
		assert_eq(result.tree.root_id, role_id + ".anchor")
		var catalog := ProgressionCatalog.from_validated_trees([result.tree])
		var summary := catalog.get_summary(role_id)
		assert_eq(summary.node_count, expected.nodes, role_id)
		assert_eq(summary.total_xp, expected.xp, role_id)
		assert_eq(summary.effect_counts, expected.effects, role_id)


func test_medic_first_aid_matches_authored_healing() -> void:
	var action := load("res://data/heroes/sands/actions/first_aid.tres") as Action
	assert_not_null(action)
	assert_eq(action.action_name, "First Aid")
	assert_eq(action.target_type, Action.TargetType.ONE_ALLY)
	assert_eq(action.effects.size(), 1)
	var healing := action.effects[0] as Effect_Healing
	assert_not_null(healing)
	assert_almost_eq(healing.potency, 0.75, 0.001)
	assert_true(healing.scales_with_missing_hp)
	assert_eq(
		action.description,
		"Heals a team member for {psy*0.75} HP, increased by their missing HP percentage.",
	)

func test_every_production_role_fulfills_the_starting_kit_contract() -> void:
	for role_id: String in STARTING_KITS:
		var hero_id: String = EXPECTED[role_id].hero
		var path := CONTENT_ROOT.path_join(hero_id).path_join(role_id + ".json")
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_eq(int(document.schema_version), 2, role_id)
		assert_eq(int(document.content_revision), 2, role_id)
		var nodes: Array = document.nodes
		_assert_authored_node_contract(nodes, AUTHORED_NODES[role_id], role_id)
		var anchors := nodes.filter(func(node): return node.get("node_kind", "progression") == "role_anchor")
		assert_eq(anchors.size(), 1, role_id)
		if anchors.size() != 1: continue
		var anchor: Dictionary = anchors[0]
		assert_eq(anchor.id, role_id + ".anchor", role_id)
		assert_eq(anchor.parent, null, role_id)
		assert_eq(int(anchor.rank), 1, role_id)
		assert_eq(int(anchor.column), 0, role_id)

		var starting := nodes.filter(func(node): return node.get("starting_owned", false) == true)
		starting.sort_custom(func(a, b): return int(a.effect.slot) < int(b.effect.slot))
		assert_eq(starting.size(), 2, role_id)
		for index in mini(starting.size(), 2):
			var node: Dictionary = starting[index]
			assert_eq(node.parent, anchor.id, node.id)
			assert_eq(int(node.rank), 1, node.id)
			assert_eq(int(node.column), -1 if index == 0 else 1, node.id)
			assert_eq(int(node.xp_cost), 0, node.id)
			assert_eq(int(node.effect.slot), index + 1, node.id)
			assert_true(str(node.effect.resource).ends_with(STARTING_KITS[role_id][index]), node.id)

		var paid := nodes.filter(func(node): return node.get("node_kind", "progression") == "progression" and not node.get("starting_owned", false))
		paid.sort_custom(func(a, b): return int(a.rank) < int(b.rank))
		assert_false(paid.is_empty(), role_id)
		if paid.is_empty(): continue
		assert_eq(int(paid[0].rank), 2, role_id)
		assert_eq(paid[0].parent, anchor.id, role_id)
		assert_eq(str(paid[0].id), str(FIRST_PAID[role_id][0]), role_id)
		_assert_exact_effect(paid[0].effect, FIRST_PAID[role_id][1], "%s first paid" % role_id)
		var paid_ranks := {}
		for node: Dictionary in paid:
			paid_ranks[int(node.rank)] = true
			var multiplier := 150 if int(node.column) != 0 else 100
			assert_eq(int(node.xp_cost), int(node.rank) * multiplier, node.id)
		for rank in range(2, int(paid[-1].rank) + 1):
			assert_true(paid_ranks.has(rank), "%s paid rank %d" % [role_id, rank])

		var result := ProgressionJsonLoader.load_file(path)
		assert_eq(result.errors.size(), 0, path)
		assert_not_null(result.tree, path)

func test_runtime_content_and_fixtures_have_no_legacy_operator_skill_references() -> void:
	var legacy_name := "in" + "spire"
	for root in ["res://data", "res://src", "res://test"]:
		_assert_tree_excludes_tokens(root, [legacy_name, legacy_name.capitalize(), legacy_name.to_upper()])

func test_all_non_stat_rewards_reference_explicit_action_resources() -> void:
	for role_id: String in EXPECTED:
		var expected: Dictionary = EXPECTED[role_id]
		var result := ProgressionJsonLoader.load_file(CONTENT_ROOT.path_join(expected.hero).path_join(role_id + ".json"))
		if result.tree == null: continue
		for node: ProgressionNodeDefinition in result.tree.nodes:
			if node.is_structural: continue
			if node.effect.type != ProgressionEffect.Type.STAT:
				assert_true(node.effect.target.begins_with("res://data/heroes/"), node.id)
				assert_true(ResourceLoader.exists(node.effect.target), node.id)
				assert_true(ResourceLoader.load(node.effect.target) is Action, node.id)

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


func test_asher_operative_role_exposes_complete_gdd_kit() -> void:
	var role := load("res://data/heroes/asher/roles/opr.tres") as RoleDefinition
	assert_not_null(role)
	assert_eq(role.role_id, "opr")
	assert_eq(
		role.description,
		"OPERATIVE[p][i]A tactical support specialist who controls enemy momentum and enables the team.",
	)
	var action_paths: Array[String] = []
	for action: Action in role.actions:
		action_paths.append(action.resource_path)
	assert_eq(action_paths, [
		"res://data/heroes/asher/actions/coordinate.tres",
		"res://data/heroes/asher/actions/decoy.tres",
		"res://data/heroes/asher/actions/debilitate.tres",
		"res://data/heroes/asher/actions/ensnare.tres",
	])
	assert_not_null(role.shift_action)
	if role.shift_action != null:
		assert_eq(
			role.shift_action.resource_path,
			"res://data/heroes/asher/actions/dismantle.tres",
		)
	assert_not_null(role.passive)
	if role.passive != null:
		assert_eq(
			role.passive.resource_path,
			"res://data/heroes/asher/actions/teamwork.tres",
		)


func test_asher_teamwork_rewards_living_team_on_enemy_breach_until_shift() -> void:
	var teamwork := load("res://data/heroes/asher/actions/teamwork.tres") as Action
	assert_eq(teamwork.effects.size(), 1)
	var apply_effect := teamwork.effects[0] as Effect_ApplyCondition
	assert_eq(apply_effect.target_type, Action.TargetType.SELF)
	var passive := apply_effect.condition
	assert_true(passive.is_passive)
	assert_eq(passive.remove_on_triggers, [Trigger.TriggerType.ON_SHIFT])
	assert_eq(passive.triggers.size(), 1)
	var breach_trigger := passive.triggers[0]
	assert_eq(breach_trigger.trigger_type, Trigger.TriggerType.ON_ENEMY_BREACHED)
	assert_eq(breach_trigger.effects_to_run.size(), 1)
	var focus_effect := breach_trigger.effects_to_run[0] as Effect_ModifyFocus
	assert_eq(focus_effect.focus_amount, 1)
	assert_eq(focus_effect.target_type, Action.TargetType.ALL_ALLIES)
	assert_string_contains(teamwork.description.to_lower(), "enemy is breached")

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

func _assert_authored_node_contract(actual_nodes: Array, expected_rows: Array, role_id: String) -> void:
	assert_eq(actual_nodes.size(), expected_rows.size(), role_id)
	for index in mini(actual_nodes.size(), expected_rows.size()):
		var actual: Dictionary = actual_nodes[index]
		var expected: Array = expected_rows[index]
		var context := "%s node %d (%s)" % [role_id, index, expected[0]]
		assert_eq(str(actual.id), str(expected[0]), context)
		assert_eq(actual.parent, expected[1], context)
		assert_eq(int(actual.rank), int(expected[2]), context)
		assert_eq(int(actual.column), int(expected[3]), context)
		assert_eq(actual.has("xp_cost"), expected[4] != null, context)
		if expected[4] != null:
			assert_eq(int(actual.xp_cost), int(expected[4]), context)
		assert_eq(str(actual.get("node_kind", "progression")), str(expected[5]), context)
		assert_eq(bool(actual.get("starting_owned", false)), bool(expected[6]), context)
		_assert_exact_effect(actual.get("effect"), expected[7], context)

func _assert_exact_effect(actual: Variant, expected: Variant, context: String) -> void:
	assert_eq(actual == null, expected == null, context)
	if actual == null or expected == null: return
	assert_eq(actual.size(), expected.size(), context)
	assert_eq(str(actual.type), str(expected.type), context)
	match str(expected.type):
		"stat":
			assert_eq(str(actual.stat), str(expected.stat), context)
			assert_eq(int(actual.amount), int(expected.amount), context)
		"action":
			assert_eq(str(actual.resource), str(expected.resource), context)
			assert_eq(int(actual.slot), int(expected.slot), context)
		"passive", "shift_action":
			assert_eq(str(actual.resource), str(expected.resource), context)

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
