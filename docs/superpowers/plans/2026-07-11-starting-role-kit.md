# Starting Role Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every unlocked role a structural role header with two free starting skills while keeping paid progression at rank 2 and eliminating every remaining Inspire reference in favor of Coordinate.

**Architecture:** Progression definitions gain explicit `role_anchor` and `starting_owned` semantics. Fresh hero/role initialization creates zero-cost ownership records before rebuilding derived combat roles; anchors remain structural and cannot enter ownership or purchase paths. A dedicated anchor control renders the centered role name while ordinary skill nodes render the two side skills and paid progression.

**Tech Stack:** Godot 4.7 test runtime, GDScript, JSON progression content, vendored GUT 9.7.1.

## Global Constraints

- No migration, reconciliation, refund, or compatibility support for existing prototype saves.
- Role unlocking remains hero progression behavior and is never granted by a tree node.
- Every production role has exactly one structural anchor and exactly two starting-owned normal action nodes.
- Starting skills cost 0 XP, occupy distinct action slots, and never reduce or refund hero XP.
- Paid progression begins at rank 2; standard node price is `rank * 100` and existing premium branch multipliers are preserved.
- Preserve stable IDs for existing effect nodes; only new anchor IDs are introduced.
- The legacy Operator skill name and resource path must be absent from tracked source, runtime content, fixtures, and tests; Operator uses Coordinate. Historical planning documents may describe the rename.
- Preserve the user's current uncommitted Coordinate resource/icon/test edits and stage only task-owned files.

---

### Task 1: Add Structural Anchor and Starting-Owned Schema Semantics

**Files:**
- Modify: `src/progression/progression_node_definition.gd`
- Modify: `src/progression/role_tree_definition.gd`
- Modify: `src/progression/progression_json_loader.gd`
- Modify: `test/unit/test_progression_definitions.gd`
- Modify: `test/unit/test_progression_json_loader.gd`
- Modify: `test/fixtures/progression/valid_role.json`

**Interfaces:**
- Produces: `ProgressionNodeDefinition.NodeKind { PROGRESSION, ROLE_ANCHOR }`.
- Produces: `node.kind`, `node.starting_owned`, `node.is_structural`, and `RoleTreeDefinition.starting_node_ids`.
- Keeps: existing `id`, `parent_id`, `rank`, `column`, `cost`, and `effect` APIs.

- [ ] **Step 1: Write failing definition tests**

Add tests constructing:

```gdscript
var anchor := ProgressionNodeDefinition.role_anchor("gun.anchor", 1, 0)
var first := ProgressionNodeDefinition.progression(
	"gun.root", "gun.anchor", 1, -1, 0,
	ProgressionEffect.action("res://data/heroes/asher/actions/double_tap.tres", 1), true,
)
var second := ProgressionNodeDefinition.progression(
	"gun.fusion_ammo", "gun.anchor", 1, 1, 0,
	ProgressionEffect.action("res://data/heroes/asher/actions/fusion_ammo.tres", 2), true,
)
var paid := ProgressionNodeDefinition.progression("gun.atk_1", "gun.anchor", 2, 0, 200, ProgressionEffect.stat("ATK", 1))
var tree := RoleTreeDefinition.new("gun", 4, [anchor, first, second, paid])
assert_true(tree.is_valid)
assert_eq(tree.root_id, "gun.anchor")
assert_eq(tree.starting_node_ids, ["gun.root", "gun.fusion_ammo"])
assert_true(anchor.is_structural)
assert_null(anchor.effect)
```

Add rejection cases for two anchors, effect/cost/ownership on an anchor, fewer or more than two starting nodes, starting nodes not rank 1, non-action starting effects, duplicate starting action slots, nonzero starting cost, and a starting node whose parent is not the anchor.

- [ ] **Step 2: Run focused tests and observe RED**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_progression_definitions.gd,res://test/unit/test_progression_json_loader.gd -gexit
```

Expected: failures for missing node kind/factories and anchor JSON support.

- [ ] **Step 3: Implement immutable node semantics**

Add `NodeKind`, factory methods, getter-only `kind`/`starting_owned`, and validation rules. `role_anchor()` creates the sole parentless structural node with rank 1, column 0, cost 0, and null effect. `progression()` retains existing effect validation and permits cost 0 only when `starting_owned` is true.

- [ ] **Step 4: Extend tree validation**

Require one root of `ROLE_ANCHOR`, exactly two starting nodes, distinct starting action slots, and anchor-parent relationships. Sort and expose `starting_node_ids` defensively. Existing paid nodes remain reachable through the anchor.

- [ ] **Step 5: Extend JSON validation and construction**

Accept:

```json
{"id":"gun.anchor","node_kind":"role_anchor","parent":null,"rank":1,"column":0}
```

For progression nodes, `node_kind` defaults to `progression` and `starting_owned` defaults false. Anchor nodes reject `effect`, `xp_cost`, and `starting_owned`; progression nodes retain them. Bump `SUPPORTED_SCHEMA_VERSION` to 2 and update the valid fixture to a complete anchor/two-starting/paid tree using Coordinate rather than Inspire.

- [ ] **Step 6: Run focused tests and commit**

Expected: focused definition/loader tests pass and `git diff --check` is silent.

```bash
git add src/progression/progression_node_definition.gd src/progression/role_tree_definition.gd src/progression/progression_json_loader.gd test/unit/test_progression_definitions.gd test/unit/test_progression_json_loader.gd test/fixtures/progression/valid_role.json
git commit -m "feat: model starting role kit nodes"
```

### Task 2: Initialize Fresh Role Progress with Zero-Cost Starting Skills

**Files:**
- Create: `src/progression/progression_initializer.gd`
- Modify: `src/progression/progression_system.gd`
- Modify: `src/singletons/save_system.gd`
- Modify: `src/progression/progression_service.gd`
- Modify: `src/progression/progression_rebuilder.gd`
- Modify: `src/progression/hero_role_progress.gd`
- Create: `test/unit/test_progression_initializer.gd`
- Modify: `test/unit/test_progression_service.gd`
- Modify: `test/unit/test_progression_rebuilder.gd`
- Modify: `test/unit/test_save_system_isolation.gd`

**Interfaces:**
- Produces: `ProgressionInitializer.initialize_hero(hero: HeroData, catalog: ProgressionCatalog) -> ProgressionRebuilder.RebuildResult`.
- Produces: `ProgressionInitializer.initialize_role(hero: HeroData, role_id: String, catalog: ProgressionCatalog) -> bool` for the future role-unlock seam.
- Produces: `ProgressionSystem.initialize_fresh_hero(hero: HeroData) -> bool`.

- [ ] **Step 1: Write failing initialization tests**

For a fresh hero with unlocked `gun`, assert:

```gdscript
assert_true(ProgressionInitializer.initialize_role(hero, "gun", catalog))
assert_eq(hero.role_progress.gun.owned_node_ids, ["gun.root", "gun.fusion_ammo"])
assert_eq(hero.role_progress.gun.xp_paid_by_node, {"gun.root": 0, "gun.fusion_ammo": 0})
assert_eq(hero.current_xp, original_xp)
```

Assert idempotency, locked-role rejection, unknown-role rejection, initialization of every unlocked role, and no mutation of unrelated progress. Assert rebuilding produces both starting actions in slots 1 and 2.

- [ ] **Step 2: Run focused tests and observe RED**

Expected: initializer APIs are missing.

- [ ] **Step 3: Permit explicit zero-paid starting ownership**

Update `HeroRoleProgress` validation to permit `0` only as persisted historical price data; purchase APIs still require positive paid-node costs. Starting IDs and zero prices are created only by `ProgressionInitializer` after consulting validated tree metadata.

- [ ] **Step 4: Implement transactional fresh initialization**

`initialize_role()` creates a new progress record at the current content revision from `tree.starting_node_ids`, records zero prices, and never overwrites existing role progress. `initialize_hero()` initializes each unlocked role and calls one `ProgressionRebuilder.rebuild(hero)`; on failure it restores original role progress and derived state.

- [ ] **Step 5: Wire fresh hero creation only**

In `SaveSystem.start_new_campaign()`, duplicate each default hero, call `ProgressionSystem.initialize_fresh_hero(hero)`, then append it. Do the same in `unlock_hero()`. Do not call the initializer from `load_game()` and do not repair existing saves.

- [ ] **Step 6: Close purchase/anchor loopholes**

`ProgressionService.purchase_node()` rejects structural and starting-owned nodes before prerequisite/XP checks. `ProgressionRebuilder` skips structural nodes and applies owned starting effects normally.

- [ ] **Step 7: Run focused/full tests and commit**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
git add src/progression src/singletons/save_system.gd test/unit/test_progression_initializer.gd test/unit/test_progression_service.gd test/unit/test_progression_rebuilder.gd test/unit/test_save_system_isolation.gd
git commit -m "feat: grant fresh role starting skills"
```

### Task 3: Render and Navigate the Role Header

**Files:**
- Create: `src/hub/role_anchor_node.gd`
- Create: `src/hub/role_anchor_node.tscn`
- Modify: `src/hub/role_panel.gd`
- Modify: `src/hub/role_panel.tscn`
- Modify: `src/hub/skill_tree_node.gd`
- Modify: `src/hub/skill_tree_panel.gd`
- Modify: `test/integration/test_hub_progression.gd`
- Modify: `test/unit/test_skill_tree_navigation.gd`

**Interfaces:**
- Produces: `RoleAnchorNode.setup(role_definition: RoleDefinition, tree: RoleTreeDefinition)`.
- Keeps: generated-node dictionary and geometric navigation keyed by stable node IDs.

- [ ] **Step 1: Write failing header rendering tests**

Instantiate a role panel containing anchor, two starting actions, and a paid rank-2 node. Assert the anchor is centered, skill 1/2 are left/right on the same row, the paid node is one vertical step below, and all four controls are focusable. Assert the anchor label uses the role name and has no XP label or purchase state.

- [ ] **Step 2: Write failing navigation and purchase tests**

Assert anchor Left/Right selects the starting skills, Down selects the rank-2 paid node, and starting skills navigate inward to the anchor. Confirm on anchor or starting skills emits no `purchase_requested`; confirm on the paid available node emits exactly once.

- [ ] **Step 3: Run focused tests and observe RED**

- [ ] **Step 4: Add the dedicated anchor control**

Use a focusable `Button`-derived control with role name/icon/description metadata, `INTERACT` cursor state, no XP label, and no purchase signal. Give it a visual treatment distinct from progression ownership without adding the removed global focus border.

- [ ] **Step 5: Render node kinds and connectors**

Export the anchor scene from `RolePanel`. Instantiate it for `ROLE_ANCHOR`; instantiate `SkillTreeNode` for progression nodes. Structural anchors are treated as satisfied parents when calculating paid-node availability. Anchor child connectors show left, right, and down links. Starting skills render owned and costless.

- [ ] **Step 6: Preserve geometric navigation**

Include the anchor in `generated_nodes` and `node_positions`. The existing geometric selector uses rank/column screen positions and stable IDs; add exact header-direction regressions and ensure focus restoration can target the anchor.

- [ ] **Step 7: Run hub/full tests and commit**

```bash
git add src/hub/role_anchor_node.gd src/hub/role_anchor_node.tscn src/hub/role_panel.gd src/hub/role_panel.tscn src/hub/skill_tree_node.gd src/hub/skill_tree_panel.gd test/integration/test_hub_progression.gd test/unit/test_skill_tree_navigation.gd
git commit -m "feat: render starting role kit header"
```

### Task 4: Reflow All Nine Production Trees and Complete Coordinate Rename

**Files:**
- Modify: `data/progression/asher/{gun,opr,snp}.json`
- Modify: `data/progression/echo/{dom,kin,psi}.json`
- Modify: `data/progression/sands/{med,stg,van}.json`
- Delete: `data/heroes/asher/actions/inspire.tres`
- Delete: `data/heroes/asher/conditions/inspire.tres`
- Retain/add: `data/heroes/asher/actions/coordinate.tres`
- Retain/add: `data/heroes/asher/conditions/coordinate.tres`
- Retain/add: `assets/graphics/icons/skills/team-idea.png`
- Modify: `test/integration/test_progression_content.gd`
- Modify: Coordinate-related progression unit tests currently dirty in the worktree
- Modify: `docs/refactor.md`

**Interfaces:**
- Consumes: Task 1 schema and Task 2 initialization.
- Produces: nine schema-v2 production trees and zero legacy Operator-skill references in runtime content, source, fixtures, or tests.

- [ ] **Step 1: Add the nine-role content contract test**

Define the exact map:

```gdscript
const STARTING_KITS := {
	"gun": ["double_tap.tres", "fusion_ammo.tres"],
	"opr": ["coordinate.tres", "decoy.tres"],
	"snp": ["mark_target.tres", "aimed_shot.tres"],
	"dom": ["displace.tres", "feedback.tres"],
	"kin": ["telekinesis.tres", "rejuvenate.tres"],
	"psi": ["focused_bolt.tres", "energy_barrier.tres"],
	"med": ["immunize.tres", "booster_shots.tres"],
	"stg": ["tempo.tres", "gambit.tres"],
	"van": ["draw_fire.tres", "overwatch.tres"],
}
```

For every production tree, assert one anchor, exact two starting resources/slots, first paid rank 2, no paid rank gaps through the current endpoint, valid parent graph, and standard/premium price agreement with new ranks.

Also assert that Operator's first paid node is `opr.hp_5` (`HP +5`) and Dominator's first paid node is `dom.psy_1` (`PSY +1`), both at rank 2 for 200 XP. First paid nodes must use a broad `HP`, `ATK`, or `PSY` effect rather than specialized `PRE`.

- [ ] **Step 2: Add the zero-Inspire repository contract**

Test production/fixture resource paths, then run:

```bash
rg -n -i "inspire" data src test
```

Expected after implementation: no output. Historical planning documents may retain the old name only where they explain the rename.

- [ ] **Step 3: Run content tests and observe RED**

- [ ] **Step 4: Reflow each JSON tree**

For each role:

- Add `<role_id>.anchor` at rank 1/column 0.
- Place skill 1 at rank 1/column -1 and skill 2 at rank 1/column 1, both starting-owned, cost 0, parent anchor.
- Reparent the former first paid node to the anchor.
- Remove the former second skill from its old paid-path position.
- Shift every node below that removed position up one rank.
- Recalculate standard prices as `rank * 100`; preserve premium-node multipliers.
- Increment `content_revision` and set schema version 2.

Add `opr.hp_5` (`HP +5`) and `dom.psy_1` (`PSY +1`) as the first paid rank-2 nodes for the currently incomplete Operator and Dominator trees.

Do not invent missing rank-10 effects. Record affected open rank-10 slots in `docs/refactor.md`.

- [ ] **Step 5: Finish Inspire → Coordinate rename**

Preserve the user's Coordinate resource, condition, icon, project registration, and test edits. Update `opr.json`, fixtures, and every remaining runtime path/name reference. Confirm the old files are deleted and `rg -n -i inspire data src test` returns no results.

- [ ] **Step 6: Run production/full tests and commit**

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
git diff --check
git add data/progression data/heroes/asher/actions data/heroes/asher/conditions assets/graphics/icons/skills/team-idea.png assets/graphics/icons/skills/team-idea.png.import test docs/refactor.md project.godot
git commit -m "feat: reflow role trees around starting kits"
```

Review the staged diff before commit so only the user's Coordinate changes and task-owned progression changes are included.

### Task 5: Full Verification and Manual Checklist

**Files:**
- Create: `docs/testing/starting-role-kit-checklist.md`
- Modify: `test/integration/test_controller_playable_loop.gd`

**Interfaces:**
- Consumes: all prior tasks.
- Produces: end-to-end proof that fresh campaigns enter hub/battle with complete starting kits and paid rank-2 progression.

- [ ] **Step 1: Extend the controller playable-loop test**

After semantic title Start creates a fresh campaign, assert every hero's unlocked roles own their exact two starting IDs with zero prices. Enter hub, focus a role header, navigate left/right/down, confirm no purchase occurs on anchor/starting skills, and verify a paid node still uses the existing purchase signal. Enter battle and assert the active role exposes starting actions in slots 1 and 2.

- [ ] **Step 2: Write the manual checklist**

Cover all nine headers, role names, left/right skill labels, connectors, rank-2 price, owned styling, zero XP change, controller/mouse navigation, combat actions, Coordinate/Decoy, Displace/Feedback, and intentionally open final ranks. State that prototype saves may be discarded and are not migration-tested.

- [ ] **Step 3: Run final verification**

```bash
rg -n -i "inspire" data src test
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
git diff --check
```

Expected: the runtime/source/test legacy-name scan is empty, import exits 0, full GUT passes, and diff check is silent.

- [ ] **Step 4: Commit**

```bash
git add test/integration/test_controller_playable_loop.gd docs/testing/starting-role-kit-checklist.md
git commit -m "test: verify starting role kits"
```
