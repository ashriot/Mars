# Endgame Battle Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a directly runnable, save-isolated battle lab with all nine hero roles fully owned, optional maximum equipment, Rank 10 enemies, and fixed encounter seeds.

**Architecture:** `EndgamePartyFactory` deep-duplicates authored heroes and constructs complete progression records through the production catalog/rebuilder. `BattleScene.setup_battle` accepts explicit roster, enemy-level, seed, and reward-policy overrides while ordinary callers retain RunManager defaults. Explicit seeds create a battle-local RNG used by head starts and damage execution. A developer-only scene hosts the production battle scene without `GameManager` and explicitly disables `BattleManager` victory rewards.

**Tech Stack:** Godot 4.6.3, typed GDScript, production progression and battle scenes, GUT 9.6.1.

## Global Constraints

- Execute this plan after the cooldown-AI foundation and enemy combat-primitives plans so the temporary production encounter and deterministic damage path use the new foundations.
- Use Godot 4.6.3 and isolated `HOME=/tmp/mars-godot-home` for all automated runs.
- The lab must not create, load, mutate, or save campaign slots.
- Primary preset: all role nodes owned, duplicated current equipment at tier 5/rank 30, no invented mods or proficiency allocations.
- Skills-only preset: all role nodes owned with authored equipment ranks.
- Enemy level override is Rank 10 and encounter seed is explicit.
- Ordinary gameplay remains on `RunManager.party_roster`, dungeon tier, and run seed when overrides are absent.
- Use an existing encounter until the separate benchmark-content review and implementation plan is approved.

---

### Task 1: Fully Developed Party Factory

**Files:**
- Create: `src/dev/endgame_party_factory.gd`
- Create: `test/unit/test_endgame_party_factory.gd`

**Interfaces:**
- Produces: `EndgamePartyFactory.EquipmentPreset { SKILLS_ONLY, MAX_EQUIPMENT }`
- Produces: `EndgamePartyFactory.BuildResult { success, error, roster }`
- Produces: `EndgamePartyFactory.build(catalog, preset) -> BuildResult`

- [ ] **Step 1: Write failing party-construction tests**

```gdscript
extends GutTest

func test_build_unlocks_every_role_and_owns_every_nonstructural_node() -> void:
	var result := EndgamePartyFactory.build(ProgressionSystem.catalog,
		EndgamePartyFactory.EquipmentPreset.SKILLS_ONLY)
	assert_true(result.success, result.error)
	assert_eq(result.roster.size(), 3)
	for hero: HeroData in result.roster:
		assert_eq(hero.unlocked_role_ids.size(), hero.role_definitions.size())
		assert_eq(hero.battle_roles.size(), hero.role_definitions.size())
		assert_eq(hero.injuries, 0)
		assert_false(hero.boon_focused)
		assert_false(hero.boon_armored)
		for role_id: String in hero.unlocked_role_ids:
			var tree := ProgressionSystem.catalog.get_role(role_id)
			var expected := tree.nodes.filter(func(node: ProgressionNodeDefinition): return not node.is_structural)
			assert_eq(hero.role_progress[role_id].owned_node_ids.size(), expected.size(), "%s/%s" % [hero.hero_id, role_id])

func test_max_equipment_uses_deep_duplicates_at_tier_five_rank_thirty() -> void:
	var authored_before := {}
	for hero_id: String in ["asher", "echo", "sands"]:
		var source: HeroData = load("res://data/heroes/%s/%s.tres" % [hero_id, hero_id])
		authored_before[hero_id] = {
			"weapon_rank": source.weapon.rank, "weapon_tier": source.weapon.tier,
			"armor_rank": source.armor.rank, "armor_tier": source.armor.tier,
		}
	var result := EndgamePartyFactory.build(ProgressionSystem.catalog,
		EndgamePartyFactory.EquipmentPreset.MAX_EQUIPMENT)
	assert_true(result.success, result.error)
	for hero: HeroData in result.roster:
		assert_eq(hero.weapon.tier, 5); assert_eq(hero.weapon.rank, 30)
		assert_eq(hero.armor.tier, 5); assert_eq(hero.armor.rank, 30)
		var authored: HeroData = load("res://data/heroes/%s/%s.tres" % [hero.hero_id, hero.hero_id])
		assert_not_same(hero.weapon, authored.weapon)
		assert_not_same(hero.armor, authored.armor)
		assert_eq(authored.weapon.rank, authored_before[hero.hero_id].weapon_rank)
		assert_eq(authored.weapon.tier, authored_before[hero.hero_id].weapon_tier)
		assert_eq(authored.armor.rank, authored_before[hero.hero_id].armor_rank)
		assert_eq(authored.armor.tier, authored_before[hero.hero_id].armor_tier)

func test_build_rejects_missing_catalog_without_partial_roster() -> void:
	var result := EndgamePartyFactory.build(null, EndgamePartyFactory.EquipmentPreset.SKILLS_ONLY)
	assert_false(result.success)
	assert_true(result.roster.is_empty())
	assert_string_contains(result.error, "catalog")
```

- [ ] **Step 2: Run and verify missing factory failure**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect endgame_party_factory -gexit
```

Expected: nonzero exit because `EndgamePartyFactory` is undefined.

- [ ] **Step 3: Implement transactional party construction**

```gdscript
extends RefCounted
class_name EndgamePartyFactory

enum EquipmentPreset { SKILLS_ONLY, MAX_EQUIPMENT }
const HERO_PATHS := [
	"res://data/heroes/asher/asher.tres",
	"res://data/heroes/echo/echo.tres",
	"res://data/heroes/sands/sands.tres",
]

class BuildResult extends RefCounted:
	var success: bool
	var error: String
	var roster: Array[HeroData] = []
	func _init(ok: bool, message: String = "", heroes: Array[HeroData] = []) -> void:
		success = ok; error = message; roster.assign(heroes)

static func build(catalog: ProgressionCatalog, preset: EquipmentPreset) -> BuildResult:
	if catalog == null: return BuildResult.new(false, "A progression catalog is required.")
	var roster: Array[HeroData] = []
	for path: String in HERO_PATHS:
		var source := load(path) as HeroData
		if source == null: return BuildResult.new(false, "Could not load hero at %s." % path)
		var hero := source.duplicate(true) as HeroData
		hero.unlocked_role_ids.assign(hero.role_definitions.map(func(role: RoleDefinition): return role.role_id))
		hero.role_progress.clear(); hero.injuries = 0; hero.boon_focused = false; hero.boon_armored = false
		for role_id: String in hero.unlocked_role_ids:
			var tree := catalog.get_role(role_id)
			if tree == null: return BuildResult.new(false, "Missing progression tree '%s'." % role_id)
			var owned: Array[String] = []
			var paid: Dictionary[String, int] = {}
			for node: ProgressionNodeDefinition in tree.nodes:
				if node.is_structural: continue
				owned.append(node.id); paid[node.id] = 0
			hero.role_progress[role_id] = HeroRoleProgress.new(tree.version, owned, paid)
		if hero.weapon: hero.weapon = hero.weapon.duplicate(true)
		if hero.armor: hero.armor = hero.armor.duplicate(true)
		if preset == EquipmentPreset.MAX_EQUIPMENT:
			for equipment: Equipment in [hero.weapon, hero.armor]:
				if equipment: equipment.tier = 5; equipment.rank = 30; equipment.current_xp = 0
		var rebuild := ProgressionRebuilder.new(catalog).rebuild(hero)
		if not rebuild.success: return BuildResult.new(false, "%s: %s" % [hero.hero_id, rebuild.error])
		roster.append(hero)
	return BuildResult.new(true, "", roster)
```

- [ ] **Step 4: Run focused tests, import, and commit**

Run the Step 2 command and isolated import. Expected: both exit zero.

```sh
git add src/dev/endgame_party_factory.gd src/dev/endgame_party_factory.gd.uid test/unit/test_endgame_party_factory.gd test/unit/test_endgame_party_factory.gd.uid
git commit -m "feat: build fully developed benchmark parties"
```

---

### Task 2: Explicit Battle Setup Overrides

**Files:**
- Modify: `src/battle/battle_scene.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/scripts/action_effects/effect_damage.gd`
- Modify: `src/battle/game_manager.gd`
- Modify: `test/unit/test_damage_effect_execution.gd`
- Modify: `test/integration/test_controller_playable_loop.gd`
- Modify: `test/integration/test_game_manager_interactions.gd`

**Interfaces:**
- Changes: `BattleScene.setup_battle(encounter, roster_override, enemy_level_override, seed_override, rewards_enabled) -> void`
- Changes: `BattleManager.spawn_encounter(roster_override, enemy_level_override, seed_override, rewards_enabled) -> void`
- Preserves: calls with only `encounter` use RunManager values and award ordinary victory XP.
- Produces: explicit seeds create a battle-local random stream for reproducible CT head starts, critical rolls, and random-hit targets; ordinary battles retain the existing global random stream.

- [ ] **Step 1: Add failing setup-override integration tests**

Use a recording `BattleManager` subclass and protect:

```gdscript
func test_battle_setup_forwards_explicit_roster_level_and_seed() -> void:
	var scene := BattleScene.new()
	var manager := RecordingSetupBattleManager.new(); scene.manager = manager
	var roster: Array[HeroData] = [HeroData.new()]
	var encounter := Encounter.new()
	scene.setup_battle(encounter, roster, 10, 4242, false)
	assert_same(manager.current_encounter, encounter)
	assert_eq(manager.received_roster, roster)
	assert_eq(manager.received_level, 10)
	assert_eq(manager.received_seed, 4242)
	assert_false(manager.received_rewards_enabled)
	scene.free(); manager.free()

func test_ordinary_setup_forwards_default_sentinels_and_rewards_enabled() -> void:
	var scene := BattleScene.new()
	var manager := RecordingSetupBattleManager.new(); scene.manager = manager
	var encounter := Encounter.new()
	scene.setup_battle(encounter)
	assert_true(manager.received_roster.is_empty())
	assert_eq(manager.received_level, -1)
	assert_eq(manager.received_seed, -1)
	assert_true(manager.received_rewards_enabled)
	scene.free(); manager.free()

func test_explicit_combat_rng_replays_and_can_return_to_default_mode() -> void:
	var manager := BattleManager.new()
	manager._configure_combat_rng(4242)
	var first := [manager.combat_random_float(), manager.combat_roll_percent(37)]
	manager._configure_combat_rng(4242)
	var second := [manager.combat_random_float(), manager.combat_roll_percent(37)]
	assert_eq(first, second)
	manager._configure_combat_rng(-1)
	assert_false(manager.has_local_combat_rng())
	manager.free()

func test_disabled_victory_rewards_do_not_change_run_xp() -> void:
	var before := RunManager.run_xp
	var manager := BattleManager.new(); manager.rewards_enabled = false
	manager._award_victory_xp(150)
	var observed := RunManager.run_xp
	RunManager.run_xp = before
	assert_eq(observed, before)
	manager.free()
```

Give `RecordingSetupBattleManager.spawn_encounter()` the same parameters and defaults, copy the roster argument, and record all four scalar arguments without entering the production spawn body.

- [ ] **Step 2: Run and verify signature failures**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect game_manager_interactions -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_effect_execution -gexit
```

Expected: nonzero exit because setup/spawn do not accept overrides.

- [ ] **Step 3: Add optional setup parameters and remove the unused export override**

Use this signature:

```gdscript
func setup_battle(encounter: Encounter, roster_override: Array[HeroData] = [],
	enemy_level_override: int = -1, seed_override: int = -1,
	rewards_enabled: bool = true) -> void:
	manager.current_encounter = encounter
	manager.spawn_encounter(roster_override, enemy_level_override, seed_override, rewards_enabled)
```

Use this spawn resolution:

```gdscript
func spawn_encounter(roster_override: Array[HeroData] = [], enemy_level_override: int = -1,
	seed_override: int = -1, allow_rewards: bool = true) -> void:
	var roster: Array[HeroData] = []
	roster.assign(roster_override if not roster_override.is_empty() else RunManager.party_roster)
	var fight_level := enemy_level_override if enemy_level_override >= 0 else RunManager.current_dungeon_tier
	encounter_seed = seed_override if seed_override >= 0 else RunManager.current_run_seed
	rewards_enabled = allow_rewards
	_configure_combat_rng(seed_override)
```

Keep the subsequent spawn statements in place, but change `for hero_data in RunManager.party_roster` to `for hero_data in roster` and retain `fight_level` as the second argument of `enemy_card.setup`.

Add the local random boundary:

```gdscript
var rewards_enabled := true
var _combat_rng: RandomNumberGenerator

func _configure_combat_rng(seed_override: int) -> void:
	if seed_override < 0:
		_combat_rng = null
		return
	_combat_rng = RandomNumberGenerator.new()
	_combat_rng.seed = seed_override

func has_local_combat_rng() -> bool:
	return _combat_rng != null

func combat_random_float() -> float:
	return _combat_rng.randf() if _combat_rng != null else randf()

func combat_roll_percent(chance: int) -> bool:
	var roll := _combat_rng.randi_range(1, 100) if _combat_rng != null else randi_range(1, 100)
	return roll <= chance

func combat_random_actor(candidates: Array) -> ActorCard:
	if candidates.is_empty(): return null
	var index := _combat_rng.randi_range(0, candidates.size() - 1) \
		if _combat_rng != null else randi_range(0, candidates.size() - 1)
	return candidates[index] as ActorCard

func _award_victory_xp(amount: int) -> void:
	if rewards_enabled: RunManager.add_run_xp(amount)
```

Use `combat_random_float()` in `_apply_initial_ct_head_starts()`, and call `_award_victory_xp(xp_reward)` from the victory path. In `Effect_Damage`, pass the manager into `_resolve_planned_target`, `_roll_percent`, and `_pick_random_target`, with these wrappers:

```gdscript
func _roll_percent(chance: int, battle_manager: BattleManager) -> bool:
	return battle_manager.combat_roll_percent(chance)

func _pick_random_target(candidates: Array, battle_manager: BattleManager) -> ActorCard:
	return battle_manager.combat_random_actor(candidates)
```

Update `_resolve_planned_target()` to accept `battle_manager` and call `_pick_random_target(_filter_valid_targets(plan_candidates), battle_manager)` for random plans. Update the two deterministic test effect subclasses in `test_damage_effect_execution.gd` to accept the manager argument while retaining their recorded outcomes.

Remove unused `hero_data_files` and `force_enemy_level` fields and their scene assignment. Leave `GameManager` calling `setup_battle(encounter)`.

- [ ] **Step 4: Run focused battle setup/full-loop tests and commit**

Run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect controller_playable_loop -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect game_manager_interactions -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_effect_execution -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_responsive_layout -gexit
git diff --check
```

Expected: all selected suites pass and both commands exit zero.

```sh
git add src/battle/battle_scene.gd src/battle/battle_manager.gd src/battle/battle_scene.tscn src/scripts/action_effects/effect_damage.gd src/battle/game_manager.gd test/unit/test_damage_effect_execution.gd test/integration/test_controller_playable_loop.gd test/integration/test_game_manager_interactions.gd
git commit -m "feat: inject explicit battle benchmark setup"
```

---

### Task 3: Directly Runnable Lab Scene

**Files:**
- Create: `src/dev/endgame_battle_lab.gd`
- Create: `src/dev/endgame_battle_lab.tscn`
- Create: `test/integration/test_endgame_battle_lab.gd`

**Interfaces:**
- Produces a directly runnable scene using an existing encounter before benchmark content exists.
- Produces: `EndgameBattleLab.start_benchmark() -> bool`

- [ ] **Step 1: Write failing lab isolation tests**

```gdscript
extends GutTest

const LabScene := preload("res://src/dev/endgame_battle_lab.tscn")

func test_lab_builds_max_party_and_forwards_rank_ten_fixed_seed() -> void:
	var lab := LabScene.instantiate() as EndgameBattleLab
	add_child_autofree(lab)
	await get_tree().process_frame
	assert_true(lab.last_build_succeeded)
	assert_eq(lab.battle_scene.manager.actor_list.filter(func(actor): return actor is HeroCard).size(), 3)
	assert_eq(lab.enemy_level, 10)
	assert_eq(lab.battle_scene.manager.encounter_seed, lab.encounter_seed)
	assert_false(lab.battle_scene.manager.rewards_enabled)

func test_lab_start_and_result_do_not_mutate_save_or_run_singletons() -> void:
	var before := _snapshot_global_state()
	var lab := LabScene.instantiate() as EndgameBattleLab
	add_child_autofree(lab)
	await get_tree().process_frame
	lab._on_battle_ended(true)
	assert_eq(_snapshot_global_state(), before)
```

Implement `_snapshot_global_state()` with Bits, SaveSystem data/roster/inventory, current slot, RunManager active/tier/seed/rewards/inventory, and file bytes for the current save slot. Restore the snapshot in `after_each()` even when assertions fail.

- [ ] **Step 2: Run and verify missing scene failure**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect endgame_battle_lab -gexit
```

Expected: nonzero exit because the lab scene does not exist.

- [ ] **Step 3: Implement a thin lab host**

```gdscript
extends Control
class_name EndgameBattleLab

@export var encounter: Encounter
@export var equipment_preset := EndgamePartyFactory.EquipmentPreset.MAX_EQUIPMENT
@export_range(1, 10, 1) var enemy_level := 10
@export var encounter_seed := 4242
@export var auto_start := true
@onready var battle_scene: BattleScene = $BattleScene
var last_build_succeeded := false

func _ready() -> void:
	if auto_start: start_benchmark()

func start_benchmark() -> bool:
	if encounter == null:
		push_error("EndgameBattleLab requires an encounter.")
		return false
	var result := EndgamePartyFactory.build(ProgressionSystem.catalog, equipment_preset)
	if not result.success:
		push_error("EndgameBattleLab: %s" % result.error)
		return false
	last_build_succeeded = true
	battle_scene.setup_battle(encounter, result.roster, enemy_level, encounter_seed, false)
	battle_scene.battle_ended.connect(_on_battle_ended)
	return true

func _on_battle_ended(won: bool) -> void:
	print("Endgame benchmark result: %s" % ("VICTORY" if won else "DEFEAT"))
```

Create a full-rect `Control` scene with this script and an instance of `res://src/battle/battle_scene.tscn`. Assign `res://data/enemies/encounters/attack_defense_drone.tres` as the temporary existing encounter. Do not instance `GameManager` or connect reward systems.

- [ ] **Step 4: Run lab, factory, layout, and save-isolation tests**

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect endgame_battle_lab -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect endgame_party_factory -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_responsive_layout -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect save_system_isolation -gexit
git diff --check
```

Expected: all commands exit zero and no ordinary save bytes change.

- [ ] **Step 5: Commit the lab**

```sh
git add src/dev/endgame_battle_lab.gd src/dev/endgame_battle_lab.gd.uid src/dev/endgame_battle_lab.tscn test/integration/test_endgame_battle_lab.gd test/integration/test_endgame_battle_lab.gd.uid
git commit -m "feat: add save-isolated endgame battle lab"
```

---

### Task 4: Battle Lab Documentation and Verification Gate

**Files:**
- Create: `docs/testing/endgame-battle-lab-checklist.md`
- Modify: `docs/README.md`

- [ ] **Step 1: Document exact launch and observation workflow**

Document running `src/dev/endgame_battle_lab.tscn` directly in Godot 4.6.3, switching between `SKILLS_ONLY` and `MAX_EQUIPMENT`, changing the exported seed, and confirming Rank 10 enemy labels. Include an unchecked results table with seed, preset, victory, total turns, defeats/revivals, role shifts, kill/Breach order, cleanses, enemy healing, unused abilities, dominant strategy, and unclear intents.

Add the checklist to `docs/README.md` with a one-line description.

- [ ] **Step 2: Run final foundation verification**

After the enemy-AI and combat-primitives plans are also complete, run:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_ability_definitions -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_ai_runtime_state -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_decision_engine -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect enemy_ai_intents -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect damage_scaling_rules -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_condition_targets -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect endgame_party_factory -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect endgame_battle_lab -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: every command exits zero. Record exact full-suite test/assertion totals and distinguish any documented certificate/shutdown diagnostics.

- [ ] **Step 3: Commit documentation**

```sh
git add docs/testing/endgame-battle-lab-checklist.md docs/README.md
git commit -m "docs: add endgame battle lab workflow"
```

- [ ] **Step 4: Stop at the skill-content review gate**

Report the working AI foundation, combat primitives, current-enemy migration, lab presets, automated totals, and outstanding manual checks. Ask the user to refine and approve the Officer, Psyker, Gang Enforcer, and Defense Drone action names, coefficients, cooldowns, triggers, selectors, buffs, and debuffs before creating any of their resources or a benchmark-content implementation plan.
