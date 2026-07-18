# First Aid Medic Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Immunize with the authored First Aid action in Medic slot 1 while retaining Immunize as dormant content.

**Architecture:** This is an authored-content replacement: the role resource and progression JSON must point to the same action resource, with integration coverage protecting that topology. First Aid remains a single `Effect_Healing` action whose description and runtime potency both state 75% PSY.

**Tech Stack:** Godot 4.6.3 resources (`.tres`), JSON progression definitions, GDScript, GUT 9.6.1.

## Global Constraints

- Use Godot 4.6.3.
- First Aid targets one ally and heals for 75% of Sands's PSY.
- Retain `immunize.tres` and its condition resources without active Medic-kit references.
- Do not rewrite historical specifications or implementation plans.
- Preserve unrelated user changes in the dirty worktree.

---

### Task 1: Replace the active Medic starting action

**Files:**
- Add: `assets/graphics/icons/skills/first-aid-kit.png`
- Add: `assets/graphics/icons/skills/first-aid-kit.png.import`
- Add/Modify: `data/heroes/sands/actions/first_aid.tres`
- Modify: `data/heroes/sands/roles/med.tres`
- Modify: `data/progression/sands/med.json`
- Modify: `test/integration/test_progression_content.gd`
- Modify: `test/integration/test_damage_content.gd`
- Modify: `docs/testing/starting-role-kit-checklist.md`

**Interfaces:**
- Consumes: `Action.TargetType.ONE_ALLY`, `Effect_Healing.potency`, Medic role action slot ordering, and progression action effects with `slot: 1`.
- Produces: `res://data/heroes/sands/actions/first_aid.tres` as Medic slot 1 in both active content authorities.

- [ ] **Step 1: Write the failing content expectations**

Change the Medic starting kit and root node expectations in `test/integration/test_progression_content.gd`:

```gdscript
"med": ["first_aid.tres", "booster_shots.tres"],
```

```gdscript
["med.root", "med.anchor", 1, -1, 0, "progression", true, {"resource":"res://data/heroes/sands/actions/first_aid.tres","slot":1,"type":"action"}],
```

Add an explicit authored-action test:

```gdscript
func test_medic_first_aid_matches_authored_healing() -> void:
	var action := load("res://data/heroes/sands/actions/first_aid.tres") as Action
	assert_not_null(action)
	assert_eq(action.action_name, "First Aid")
	assert_eq(action.target_type, Action.TargetType.ONE_ALLY)
	assert_eq(action.effects.size(), 1)
	var healing := action.effects[0] as Effect_Healing
	assert_not_null(healing)
	assert_almost_eq(healing.potency, 0.75, 0.001)
	assert_eq(action.description, "Heals a team member for {psy*0.75} HP.")
```

- [ ] **Step 2: Run the focused test to verify RED**

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect progression_content -gexit
```

Expected: FAIL because Medic still references `immunize.tres` and First Aid's description still says `{psy*1.5}`.

- [ ] **Step 3: Make First Aid's authored behavior internally consistent**

Keep its single healing effect at:

```ini
potency = 0.75
```

Change its description to:

```ini
description = "Heals a team member for {psy*0.75} HP."
```

Keep `target_type = 5`, which is `Action.TargetType.ONE_ALLY`.

- [ ] **Step 4: Replace both active Medic references**

In `data/heroes/sands/roles/med.tres`, reference First Aid's existing resource UID and path, then keep it first in the `actions` array:

```ini
[ext_resource type="Resource" uid="uid://vbhxh66s54t6" path="res://data/heroes/sands/actions/first_aid.tres" id="2_633w3"]
```

In `data/progression/sands/med.json`, change only `med.root.effect.resource`:

```json
"resource": "res://data/heroes/sands/actions/first_aid.tres"
```

Do not edit or delete the Immunize action or condition resources.

- [ ] **Step 5: Update the active manual checklist**

Change the Medic row in `docs/testing/starting-role-kit-checklist.md` to:

```markdown
| Sands | `med` | Medic | First Aid | Booster Shots |
```

- [ ] **Step 6: Run focused verification to verify GREEN**

Run the isolated import:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars --editor --quit
```

Expected: exit 0 with no parser or resource-loading errors.

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gselect progression_content -gexit
```

Expected: all `progression_content` tests pass, including the new First Aid assertions.

- [ ] **Step 7: Run broader verification**

If the production-content formula audit rejects First Aid's direct healing formula, add `first_aid.tres` and `{psy*0.75}` to the approved formula map and the explicit set of direct-healing actions deferred from nested-condition parity. Preserve First Aid's separate potency assertion in `test_progression_content.gd`.

Run:

```bash
env HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Expected: no new failures compared with the known unrelated cursor-asset and dungeon-layout failures in the dirty worktree.

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 8: Commit only the replacement files**

```bash
git add assets/graphics/icons/skills/first-aid-kit.png assets/graphics/icons/skills/first-aid-kit.png.import data/heroes/sands/actions/first_aid.tres data/heroes/sands/roles/med.tres data/progression/sands/med.json test/integration/test_progression_content.gd docs/testing/starting-role-kit-checklist.md docs/superpowers/plans/2026-07-17-first-aid-medic-replacement.md
git commit -m "feat: replace Immunize with First Aid"
```
