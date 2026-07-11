# Progression System Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace nested editor-authored skill trees and UI-owned purchases with validated JSON role trees, stable node IDs, typed effects, and atomic hero-specific progression transactions.

**Architecture:** A startup-loaded `ProgressionCatalog` owns immutable role-tree definitions parsed from JSON. A non-UI `ProgressionService` validates and commits purchases against hero-owned progression records, while one `ProgressionEffectApplier` rebuilds stats and battle kits. The legacy resource path remains operational until all content and hub consumers have migrated, then is removed.

**Tech Stack:** Godot 4.7, GDScript, JSON, GUT 9.7.1

## Global Constraints

- XP and purchases remain hero-specific.
- Role unlocking remains separate from node progression.
- One prerequisite parent maximum and exactly one effect per node.
- JSON loads at startup only; no hot reload or custom editor.
- Stable authored node IDs must not depend on order, ancestry, rank, or column.
- Existing prototype progression saves may be reset; no legacy-ID migration.
- Store accepted content revision and historical XP paid, but do not implement refunds or resets.
- Revision mismatches must be reported without silently mutating progression.
- Preserve existing 25% rare-component behavior and all completed stabilization behavior.
- Preserve unrelated user-owned dirty files.

---

### Task 1: Immutable Progression Definitions and Typed Effects

**Files:**
- Create: `src/progression/progression_effect.gd`
- Create: `src/progression/progression_node_definition.gd`
- Create: `src/progression/role_tree_definition.gd`
- Test: `test/unit/test_progression_definitions.gd`

**Interfaces:**
- Produces: `ProgressionEffect`, `ProgressionNodeDefinition`, and `RoleTreeDefinition`
- `RoleTreeDefinition.get_node(node_id: String) -> ProgressionNodeDefinition`
- `RoleTreeDefinition.get_children(node_id: String) -> Array[ProgressionNodeDefinition]`

- [ ] **Step 1: Write failing definition tests**

Cover immutable field construction, node lookup, deterministic child ordering by `(rank, column, id)`, and the fact that changing layout/order does not change IDs.

```gdscript
func test_role_tree_indexes_nodes_without_deriving_identity() -> void:
	var root := ProgressionNodeDefinition.new("gun.root", "", 1, 0, 100, ProgressionEffect.stat("ATK", 1))
	var child := ProgressionNodeDefinition.new("gun.burst", "gun.root", 2, 1, 200, ProgressionEffect.action("res://example.tres", 1))
	var tree := RoleTreeDefinition.new("gun", 1, [child, root])
	assert_eq(tree.root_id, "gun.root")
	assert_true(is_same(tree.get_node("gun.burst"), child))
	assert_eq(tree.get_children("gun.root").map(func(node): return node.id), ["gun.burst"])
```

- [ ] **Step 2: Run the suite and verify RED**

Run the full isolated GUT command. Expected: parse/type failures because the three definition classes do not exist.

- [ ] **Step 3: Implement minimal immutable definitions**

Use private backing fields with read-only getters. `ProgressionEffect` supports `STAT`, `ACTION`, `PASSIVE`, and `SHIFT_ACTION`, with typed factory methods. `RoleTreeDefinition` builds node and child indexes once in its constructor and exposes duplicates of arrays where mutation would otherwise leak.

- [ ] **Step 4: Run tests and verify GREEN**

Expected: definition tests and the existing full suite pass.

- [ ] **Step 5: Commit**

```bash
git add src/progression test/unit/test_progression_definitions.gd
git commit -m "feat: add immutable progression definitions"
```

---

### Task 2: JSON Loader, Validation, Catalog, and Content Summary

**Files:**
- Create: `src/progression/progression_content_error.gd`
- Create: `src/progression/progression_json_loader.gd`
- Create: `src/progression/progression_catalog.gd`
- Create: `test/fixtures/progression/valid_role.json`
- Create: `test/fixtures/progression/duplicate_node.json`
- Create: `test/fixtures/progression/missing_parent.json`
- Create: `test/fixtures/progression/multiple_roots.json`
- Create: `test/fixtures/progression/cycle.json`
- Create: `test/fixtures/progression/invalid_effect.json`
- Create: `test/unit/test_progression_json_loader.gd`

**Interfaces:**
- Consumes: Task 1 definition classes
- Produces: `ProgressionJsonLoader.load_file(path: String) -> LoadResult`
- Produces: `ProgressionCatalog.load_directory(path: String) -> Error`
- Produces: `ProgressionCatalog.get_role(role_id: String) -> RoleTreeDefinition`
- Produces: `ProgressionCatalog.get_summary(role_id: String) -> Dictionary`

- [ ] **Step 1: Add schema fixtures and failing validation tests**

Tests cover valid loading plus unsupported schema, duplicate IDs, namespace mismatch, missing parents, multiple roots, cycles, unreachable nodes, nonpositive costs, invalid layout integers, unknown stats/effects, invalid resource paths/classes, and invalid action slots. Assert errors contain source path, node ID where applicable, field, and reason.

- [ ] **Step 2: Verify RED**

Run `test_progression_json_loader.gd`; expected failure because loader/catalog classes are absent.

- [ ] **Step 3: Implement parse-then-validate loading**

Parse into temporary dictionaries, validate the complete document, and construct immutable definitions only after validation succeeds. Never return a partial tree. Use `JSON.parse()`, `ResourceLoader.exists()`, and expected script classes for referenced resources.

`LoadResult` contains either `tree` or an ordered array of `ProgressionContentError`; it never contains both.

- [ ] **Step 4: Implement catalog and summary**

Directory loading sorts filenames for deterministic behavior, rejects duplicate role IDs, and commits the new catalog only after every file validates. Summary includes role ID, revision, node count, total XP, maximum rank, branch count, and counts by effect type.

- [ ] **Step 5: Verify GREEN and commit**

Run focused and full suites, then commit all Task 2 files:

```bash
git commit -m "feat: load and validate progression json"
```

---

### Task 3: Hero Progression Records and Atomic Purchase Service

**Files:**
- Create: `src/progression/hero_role_progress.gd`
- Create: `src/progression/progression_purchase_result.gd`
- Create: `src/progression/progression_service.gd`
- Modify: `src/scripts/data/hero_data.gd`
- Test: `test/unit/test_progression_service.gd`
- Test: `test/integration/test_hub_progression.gd`

**Interfaces:**
- Consumes: `ProgressionCatalog.get_role()`
- Produces: `HeroRoleProgress` with `content_revision`, `owned_node_ids`, and `xp_paid_by_node`
- Produces: `ProgressionService.purchase_node(hero: HeroData, role_id: String, node_id: String) -> ProgressionPurchaseResult`
- Produces statuses: `PURCHASED`, `INVALID_HERO`, `ROLE_LOCKED`, `NODE_NOT_FOUND`, `ALREADY_OWNED`, `PREREQUISITE_LOCKED`, `INSUFFICIENT_XP`, `INVALID_EFFECT`, `REVISION_MISMATCH`

- [ ] **Step 1: Write one failing test for every result**

Each rejection snapshots XP and progression records and asserts zero mutation. Successful purchase asserts exactly one deduction, ownership, historical price, accepted revision, and typed result payload.

Add duplicate-call coverage proving the second purchase is `ALREADY_OWNED` and cannot spend twice.

- [ ] **Step 2: Verify RED**

Expected: missing record/service/result classes.

- [ ] **Step 3: Add per-role hero state and save representation**

Add `role_progress: Dictionary[String, HeroRoleProgress]` to `HeroData`. Save dictionaries contain role revision, owned IDs, and exact prices paid. Loading rejects malformed record shapes and reports revision mismatch without resetting or refunding.

During the prototype cutover, absent new-format progression initializes clean role records; do not translate `unlocked_node_ids`.

- [ ] **Step 4: Implement validate-then-commit purchasing**

Perform all validation before mutation. Validate effect references through the already-loaded definition. On success, deduct XP and write ownership/price/revision as one commit section; then invoke the derived-state rebuild interface introduced in Task 4. Until Task 4 lands, inject a callable rebuild seam in tests.

- [ ] **Step 5: Verify GREEN and commit**

Run focused/full tests and commit:

```bash
git commit -m "feat: add atomic hero progression purchases"
```

---

### Task 4: Unified Effect Application and Derived-State Rebuild

**Files:**
- Create: `src/progression/progression_effect_applier.gd`
- Create: `src/progression/progression_rebuilder.gd`
- Modify: `src/scripts/data/hero_data.gd`
- Test: `test/unit/test_progression_rebuilder.gd`

**Interfaces:**
- Consumes: catalog definitions and `HeroRoleProgress`
- Produces: `ProgressionRebuilder.rebuild(hero: HeroData) -> RebuildResult`
- Produces: actor stats and `battle_roles` without mutating content definitions

- [ ] **Step 1: Write failing effect and rebuild tests**

Cover stat, action slot, passive, and shift-action effects; deterministic role/node order; equipment/base stats; locked roles; missing owned IDs; invalid effect resources; and repeat rebuild idempotency.

- [ ] **Step 2: Verify RED**

Expected: missing effect applier/rebuilder.

- [ ] **Step 3: Implement one dispatcher**

`ProgressionEffectApplier` is the only match over effect type. `ProgressionRebuilder` starts from base/equipment state, iterates catalog order, applies owned effects, and commits newly built stats/roles only after the entire rebuild succeeds.

- [ ] **Step 4: Replace service rebuild seam**

Wire successful purchases to the real rebuilder. If rebuild fails, roll back the purchase commit using the captured pre-purchase XP and role record, and return `INVALID_EFFECT`.

- [ ] **Step 5: Verify GREEN and commit**

```bash
git commit -m "refactor: unify progression effect rebuilding"
```

---

### Task 5: Hub Rendering and Purchase Integration

**Files:**
- Modify: `src/hub/role_panel.gd`
- Modify: `src/hub/skill_tree_panel.gd`
- Modify: `src/hub/party_menu.gd`
- Modify: `skill_tree_node.gd`
- Test: `test/integration/test_hub_progression.gd`

**Interfaces:**
- Consumes: immutable `RoleTreeDefinition`, `ProgressionNodeDefinition`, and `ProgressionService.purchase_node()`
- Preserves: exactly-once save/stat refresh and all-visible-tree affordability refresh

- [ ] **Step 1: Rewrite integration tests against the service boundary**

Tests assert the UI submits IDs rather than mutating XP/unlock arrays; saves only on `PURCHASED`; rejected purchases do not save; sibling affordability and XP labels refresh immediately; selection/page/node instances remain stable; and audio feedback follows the result.

- [ ] **Step 2: Verify RED against legacy UI ownership**

Expected: tests fail because `RolePanel` still calls `spend_xp()`, `unlock_node()`, and `rebuild_battle_roles()` directly.

- [ ] **Step 3: Render flat indexed definitions**

Render nodes using explicit `rank` and `column`. Resolve arrows/links through parent-child indexes. Remove UI reliance on generated IDs, traversal-derived costs, and `RoleDefinition.actions[action_slot_index]`.

- [ ] **Step 4: Delegate purchases and react to results**

`RolePanel` emits a purchase request containing hero, role ID, and node ID. `PartyMenu` invokes the service and performs save/audio/refresh only from its typed result. Keep exactly one owner of the successful side-effect chain.

- [ ] **Step 5: Verify GREEN and commit**

```bash
git commit -m "refactor: route hub purchases through progression service"
```

---

### Task 6: Convert Every Role Tree to JSON and Load at Startup

**Files:**
- Create: `data/progression/asher/gun.json`
- Create: `data/progression/asher/snp.json`
- Create: `data/progression/asher/opr.json`
- Create: `data/progression/echo/kin.json`
- Create: `data/progression/echo/psi.json`
- Create: `data/progression/echo/dom.json`
- Create: `data/progression/sands/med.json`
- Create: `data/progression/sands/stg.json`
- Create: `data/progression/sands/van.json`
- Modify: `src/scripts/data/role_definition.gd`
- Modify: `project.godot`
- Create: `src/progression/progression_system.gd`
- Create: `test/integration/test_progression_content.gd`

**Interfaces:**
- Produces autoload: `ProgressionSystem.catalog: ProgressionCatalog`
- Produces autoload: `ProgressionSystem.service: ProgressionService`
- `RoleDefinition` retains combat/visual metadata and references its JSON role ID; it no longer owns tree topology

- [ ] **Step 1: Add failing production-content parity tests**

For every current role, assert JSON validation, expected role ID/root, node count, total XP, effect count/type, explicit action/passive/shift resources, and stable IDs matching the intended new naming table. Do not compare legacy generated IDs as the new IDs are intentionally authored.

- [ ] **Step 2: Convert one representative role**

Manually convert one complete branching role, validate its summary, and test it in the loader before bulk conversion. Record the stable ID naming convention in the test fixture/comments.

- [ ] **Step 3: Convert remaining roles**

Create one readable JSON file per role with deterministic node ordering. Explicitly review every legacy node reward, cost, prerequisite, rank, and visual column during conversion.

- [ ] **Step 4: Add startup composition root**

`ProgressionSystem._ready()` loads `res://data/progression/`, publishes catalog/service only on complete success, and reports all validation errors before aborting initialization. Register it as an autoload before gameplay consumers.

- [ ] **Step 5: Verify all content and commit**

Run content integration tests, full suite, and headless editor parse. Commit JSON and startup wiring:

```bash
git commit -m "feat: load role progression from json"
```

---

### Task 7: Remove Legacy Node Resources and Traversal Code

**Files:**
- Delete: `src/scripts/data/role_node.gd`
- Delete: legacy `data/heroes/*/roles/<role>/*.tres` node resources
- Modify: `src/scripts/data/role_definition.gd`
- Modify: `src/scripts/data/hero_data.gd`
- Modify: `src/hub/role_panel.gd`
- Modify: `skill_tree_node.gd`
- Modify: affected `.tscn` script-class/resource references
- Modify: `test/integration/test_hub_progression.gd`
- Modify: progression unit/integration tests as required for final API names only

**Interfaces:**
- Removes: `RoleNode`, `root_node`, `init_structure()`, `generated_id`, `calculated_xp_cost`, `unlocked_node_ids`, `unlock_node()`, direct `spend_xp()` purchase sequencing, `_process_node_stats()`, and `_bake_tree_into_role()`

- [ ] **Step 1: Add a legacy-reference guard test**

Scan production scripts/scenes/resources and fail if any reference remains to the removed classes, properties, methods, or legacy node-resource directories.

- [ ] **Step 2: Verify RED**

Expected: the guard lists all remaining legacy references.

- [ ] **Step 3: Remove legacy production paths and content**

Delete only after Tasks 1–6 are green. Update scenes and type annotations to immutable definitions. Do not retain dual-write or fallback behavior.

- [ ] **Step 4: Verify prototype save reset behavior**

Loading a pre-redesign save must initialize clean new-format role progression and report the intentional incompatibility; it must not guess mappings from positional IDs.

- [ ] **Step 5: Run complete verification**

Run:

```bash
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
git diff --check
git status --short
```

Expected: every test passes, project parsing exits 0, no legacy references remain, test save data stays isolated, and unrelated user files are untouched.

- [ ] **Step 6: Perform manual verification**

For at least two heroes and two branching roles each:

- Open the hub and switch roles/pages.
- Confirm explicit layout and prerequisites.
- Purchase stat and ability nodes.
- Confirm exact XP deduction, immediate sibling affordability, stats, and combat abilities.
- Restart and confirm new-format persistence.
- Enter a dungeon and verify battle roles/actions.
- Confirm a revision mismatch reports clearly without reset/refund.

- [ ] **Step 7: Update architecture/refactor documentation and commit**

Document the completed boundary and leave refund/reconciliation in the deferred backlog.

```bash
git commit -m "refactor: remove legacy skill tree resources"
```
