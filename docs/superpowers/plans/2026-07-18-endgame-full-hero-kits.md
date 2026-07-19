# Endgame Full Hero Kits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the endgame battle lab expose every authored hero action, passive, and Shift action while retaining all progression-derived stats and default tier-5, rank-30 equipment.

**Architecture:** `EndgamePartyFactory` continues to own all JSON progression nodes and rebuild through `ProgressionRebuilder`. After the rebuild succeeds, it overlays non-empty/non-null kit fields from each `RoleDefinition` onto the corresponding benchmark-only `RoleData`, preserving JSON-derived fields when a role definition omits them.

**Tech Stack:** Godot 4.6.3, typed GDScript, JSON-backed progression, GUT 9.6.1.

## Global Constraints

- Do not modify campaign progression JSON or ordinary progression rebuilding.
- Do not mutate authored hero, role, action, weapon, or armor resources.
- Preserve JSON-only Operative actions when its role definition is empty.
- `MAX_EQUIPMENT` remains tier 5, rank 30, current XP 0 on deep duplicates.
- `SKILLS_ONLY` retains authored equipment progression on deep duplicates.
- Use a fresh isolated `HOME` under `/tmp` for every automated Godot run.
- Preserve and do not stage unrelated user changes already present in the working tree.

---

### Task 1: Overlay Complete Authored Kits in the Benchmark Factory

**Files:**
- Modify: `src/dev/endgame_party_factory.gd`
- Modify: `test/unit/test_endgame_party_factory.gd`

**Interfaces:**
- Preserves: `EndgamePartyFactory.build(catalog, preset) -> BuildResult`
- Produces: each non-empty `RoleDefinition.actions` list, non-null passive, and non-null Shift action on the rebuilt benchmark `RoleData`.
- Preserves: progression-derived role fields when the corresponding role-definition field is empty or null.

- [ ] **Step 1: Write the failing complete-kit regression**

Add a focused test after the existing node-ownership test:

```gdscript
func test_build_overlays_complete_authored_role_kits_and_preserves_json_only_fields() -> void:
	var result := EndgamePartyFactory.build(
		ProgressionSystem.catalog,
		EndgamePartyFactory.EquipmentPreset.SKILLS_ONLY,
	)
	assert_true(result.success, result.error)

	for hero: HeroData in result.roster:
		for definition: RoleDefinition in hero.role_definitions:
			var role := hero.battle_roles.get(definition.role_id) as RoleData
			assert_not_null(role, "%s/%s" % [hero.hero_id, definition.role_id])
			if not definition.actions.is_empty():
				assert_eq(role.actions.size(), definition.actions.size(), definition.role_id)
				for action_index in definition.actions.size():
					assert_same(role.actions[action_index], definition.actions[action_index])
			if definition.passive != null:
				assert_same(role.passive, definition.passive, definition.role_id)
			if definition.shift_action != null:
				assert_same(role.shift_action, definition.shift_action, definition.role_id)

	var echo := result.roster.filter(func(hero: HeroData) -> bool: return hero.hero_id == "echo")[0]
	var psion := echo.battle_roles["psi"] as RoleData
	assert_has(psion.actions.map(func(action: Action) -> String: return action.action_name), "Mind Storm")

	var asher := result.roster.filter(func(hero: HeroData) -> bool: return hero.hero_id == "asher")[0]
	var operative := asher.battle_roles["opr"] as RoleData
	assert_eq(
		operative.actions.map(func(action: Action) -> String: return action.action_name),
		["Coordinate", "Decoy"],
	)
```

- [ ] **Step 2: Run the focused test and confirm substantive RED**

Run:

```sh
env HOME=/tmp/mars-endgame-full-kits-red /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect endgame_party_factory -gexit
```

Expected: the new test fails because rebuilt roles omit authored skills such as Mind Storm; existing equipment and ownership cases remain green. Inspect output because GUT can exit zero despite parser or selector errors.

- [ ] **Step 3: Apply the benchmark-only authored-kit overlay**

Immediately after the successful `ProgressionRebuilder.rebuild(hero)` check and before appending the hero, add:

```gdscript
		for definition: RoleDefinition in hero.role_definitions:
			var role := hero.battle_roles.get(definition.role_id) as RoleData
			if role == null:
				return BuildResult.new(
					false,
					"%s: rebuilt role '%s' is missing." % [hero.hero_id, definition.role_id],
				)
			if not definition.actions.is_empty():
				role.actions.assign(definition.actions)
			if definition.passive != null:
				role.passive = definition.passive
			if definition.shift_action != null:
				role.shift_action = definition.shift_action
```

Do not change `ProgressionRebuilder` or progression JSON. Existing max-equipment construction already sets both weapon and armor to tier 5/rank 30/current XP 0 and remains protected by the existing factory and lab assertions.

- [ ] **Step 4: Run focused GREEN verification**

Run the factory and lab selectors separately with a newly created isolated home:

```sh
env HOME=/tmp/mars-endgame-full-kits-green /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-endgame-full-kits-green /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect endgame_party_factory -gexit
env HOME=/tmp/mars-endgame-full-kits-green /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect endgame_battle_lab -gexit
```

Expected: import exits zero; every selected test passes; Mind Storm is present; Operative retains Coordinate/Decoy; all lab equipment assertions remain tier 5/rank 30.

- [ ] **Step 5: Run final verification**

Run:

```sh
env HOME=/tmp/mars-endgame-full-kits-final /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-endgame-full-kits-final /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
env HOME=/tmp/mars-endgame-full-kits-final /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --quit-after 900 res://src/dev/endgame_battle_lab.tscn
git diff --check
```

Expected: clean import, complete suite with zero failures, direct launch reaches `PLAYER_ACTION`, and diff check is clean. Record exact test/assertion totals and distinguish documented macOS certificate/shutdown diagnostics.

- [ ] **Step 6: Commit the implementation**

```sh
git add src/dev/endgame_party_factory.gd test/unit/test_endgame_party_factory.gd
git commit -m "fix: include complete hero kits in battle lab"
```

Commit only the two task files; leave all unrelated user changes unstaged.
